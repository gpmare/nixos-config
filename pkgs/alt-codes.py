#!/usr/bin/env python3
"""Windows-style Alt+numpad codes for Plasma/Wayland (any app, any layout).

Hold Left Alt, type digits on the numpad, release Alt:
  Alt+130  -> CP850 (OEM) char   (é)
  Alt+0233 -> CP1252 (ANSI) char (é)

How it works
  * Grabs every physical keyboard (evdev) and forwards all events through
    one virtual uinput keyboard, so normal typing is unchanged.
  * New keyboards (Bluetooth reconnect, USB replug, resume) are picked up
    within ~1 s; a lost keyboard has its held keys released on the virtual
    device, so nothing (Alt, Shift, Caps) is left stuck.
  * The character is NOT typed with ydotool (ydotool only knows ASCII on a
    US keymap). Instead we emit a Compose sequence (Compose = Menu key):
      1. If the stock en_US.UTF-8 Compose table has a sequence for the
         character made only of plain keys (e.g. Compose ' e -> é,
         Compose " e -> ë, Compose = E -> €), we type that. Every toolkit
         knows the stock table, including Chromium/Electron on Wayland,
         which ships its own built-in copy and ignores ~/.XCompose.
      2. Otherwise (box-drawing etc.) we fall back to
            Compose KP_Divide KP_Multiply d d d d
         (dddd = decimal code point), defined in the ~/.XCompose table that
         `alt-codes --compose` generates. Qt/GTK/X11/kitty honour that;
         Chromium/Electron on Wayland do not.
    Taps are spaced a few ms apart, and Caps Lock (tracked from the
    compositor's LED events) is compensated so letters keep their case.
  * Keyboard LEDs (Caps/Num Lock) from the compositor are mirrored back to
    the grabbed keyboards.
"""

import os
import re
import sys
import time
from select import select

from evdev import InputDevice, UInput, UInputError, ecodes, list_devices

RESCAN_S = 1.0
VIRTUAL_NAME = os.environ.get("ALT_CODES_VIRTUAL_NAME", "alt-codes-virtual-kbd")
SKIP_NAME = ("alt-codes", "ydotool", "ydotoold", "keyd", "whisper", "avrcp")
ONLY = os.environ.get("ALT_CODES_ONLY")  # tests: grab only this device name

NUMPAD = {getattr(ecodes, f"KEY_KP{i}"): str(i) for i in range(10)}
DIGIT_KEY = {str(i): getattr(ecodes, f"KEY_{i}") for i in range(10)}
PREFIX = (ecodes.KEY_COMPOSE, ecodes.KEY_KPSLASH, ecodes.KEY_KPASTERISK)
TAP_DELAY_S = 0.004
SYSTEM_COMPOSE = os.environ.get("ALT_CODES_SYSTEM_COMPOSE")

# keysym name -> (evdev key, needs Shift) on a US/za layout
_K = ecodes
PLAIN: dict[str, tuple[int, bool]] = {}
for _c in "abcdefghijklmnopqrstuvwxyz":
    PLAIN[_c] = (getattr(_K, f"KEY_{_c.upper()}"), False)
    PLAIN[_c.upper()] = (getattr(_K, f"KEY_{_c.upper()}"), True)
for _i in range(10):
    PLAIN[str(_i)] = (getattr(_K, f"KEY_{_i}"), False)
for _name, _key, _sh in [
    ("space", "SPACE", False), ("apostrophe", "APOSTROPHE", False),
    ("quotedbl", "APOSTROPHE", True), ("comma", "COMMA", False),
    ("less", "COMMA", True), ("period", "DOT", False),
    ("greater", "DOT", True), ("slash", "SLASH", False),
    ("question", "SLASH", True), ("semicolon", "SEMICOLON", False),
    ("colon", "SEMICOLON", True), ("minus", "MINUS", False),
    ("underscore", "MINUS", True), ("equal", "EQUAL", False),
    ("plus", "EQUAL", True), ("bracketleft", "LEFTBRACE", False),
    ("braceleft", "LEFTBRACE", True), ("bracketright", "RIGHTBRACE", False),
    ("braceright", "RIGHTBRACE", True), ("backslash", "BACKSLASH", False),
    ("bar", "BACKSLASH", True), ("grave", "GRAVE", False),
    ("asciitilde", "GRAVE", True), ("exclam", "1", True), ("at", "2", True),
    ("numbersign", "3", True), ("dollar", "4", True), ("percent", "5", True),
    ("asciicircum", "6", True), ("ampersand", "7", True),
    ("asterisk", "8", True), ("parenleft", "9", True),
    ("parenright", "0", True),
]:
    PLAIN[_name] = (getattr(_K, f"KEY_{_key}"), _sh)
_PUNCT = {
    "space": " ", "apostrophe": "'", "quotedbl": '"', "comma": ",",
    "less": "<", "period": ".", "greater": ">", "slash": "/",
    "question": "?", "semicolon": ";", "colon": ":", "minus": "-",
    "underscore": "_", "equal": "=", "plus": "+", "bracketleft": "[",
    "braceleft": "{", "bracketright": "]", "braceright": "}",
    "backslash": "\\", "bar": "|", "grave": "`", "asciitilde": "~",
    "exclam": "!", "at": "@", "numbersign": "#", "dollar": "$",
    "percent": "%", "asciicircum": "^", "ampersand": "&", "asterisk": "*",
    "parenleft": "(", "parenright": ")",
}
DIRECT = {_PUNCT.get(n, n): v for n, v in PLAIN.items()}  # ASCII char -> key
LETTER_KEYS = {getattr(_K, f"KEY_{c}") for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"}

_LINE = re.compile(r'^\s*((?:<[A-Za-z0-9_]+>\s*)+):\s*"((?:[^"\\]|\\.)*)"')


def stock_sequences(path: str | None) -> dict[str, list[str]]:
    """char -> shortest stock Compose sequence (keysym names after Multi_key)
    that uses only PLAIN keys and is not a prefix of a longer sequence."""
    if not path:
        return {}
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return {}
    seqs: list[tuple[tuple[str, ...], str]] = []
    for line in text.splitlines():
        m = _LINE.match(line)
        if not m:
            continue
        syms = tuple(re.findall(r"<([A-Za-z0-9_]+)>", m.group(1)))
        val = re.sub(r"\\(.)", r"\1", m.group(2))
        seqs.append((syms, val))
    prefixes = {s[:i] for s, _ in seqs for i in range(1, len(s))}
    best: dict[str, tuple[str, ...]] = {}
    for syms, val in seqs:
        if len(val) != 1 or syms[0] != "Multi_key" or syms in prefixes:
            continue
        if not all(k in PLAIN for k in syms[1:]):
            continue
        cur = best.get(val)
        if cur is None or (len(syms), syms) < (len(cur), cur):
            best[val] = syms
    return {ch: list(s[1:]) for ch, s in best.items()}


def alt_to_char(digits: str) -> str | None:
    if not digits:
        return None
    n = int(digits) % 256  # Windows wraps Alt+256.. the same way
    if n == 0:
        return None
    codepage = "cp1252" if digits.startswith("0") else "cp850"
    try:
        ch = bytes([n]).decode(codepage)
    except UnicodeDecodeError:
        return None
    if ord(ch) < 32 or ord(ch) == 127:
        return None
    return ch


def all_chars() -> list[str]:
    out: set[str] = set()
    for n in range(1, 256):
        for d in (str(n), "0" + str(n)):
            ch = alt_to_char(d)
            if ch:
                out.add(ch)
    return sorted(out)


def compose_table() -> str:
    lines = ['include "%L"', ""]
    for ch in all_chars():
        cp = f"{ord(ch):04d}"
        keys = " ".join(f"<{d}>" for d in cp)
        q = ch.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(
            f'<Multi_key> <KP_Divide> <KP_Multiply> {keys} : "{q}" U{ord(ch):04X}'
        )
    return "\n".join(lines) + "\n"


def is_keyboard(dev: InputDevice) -> bool:
    name = (dev.name or "")
    if ONLY is not None:
        return name == ONLY
    if any(s in name.lower() for s in SKIP_NAME):
        return False
    keys = set(dev.capabilities().get(ecodes.EV_KEY, []))
    return ecodes.KEY_A in keys and ecodes.KEY_LEFTALT in keys


class Out:
    def __init__(self) -> None:
        keys = [k for k in ecodes.keys if isinstance(k, int) and 0 < k < 0x2FF]
        caps = {
            ecodes.EV_KEY: keys,
            ecodes.EV_LED: [ecodes.LED_NUML, ecodes.LED_CAPSL, ecodes.LED_SCROLLL],
        }
        self.ui = UInput(caps, name=VIRTUAL_NAME)
        self.caps_lock = False  # from compositor LED feedback
        self.stock = stock_sequences(SYSTEM_COMPOSE)
        print(f"alt-codes: {len(self.stock)} chars via stock Compose", flush=True)

    def key(self, code: int, value: int) -> None:
        self.ui.write(ecodes.EV_KEY, code, value)
        self.ui.syn()

    def tap(self, code: int, shift: bool = False) -> None:
        if code in LETTER_KEYS and self.caps_lock:
            shift = not shift
        if shift:
            self.key(ecodes.KEY_LEFTSHIFT, 1)
            time.sleep(TAP_DELAY_S)
        self.key(code, 1)
        time.sleep(TAP_DELAY_S)
        self.key(code, 0)
        time.sleep(TAP_DELAY_S)
        if shift:
            self.key(ecodes.KEY_LEFTSHIFT, 0)
            time.sleep(TAP_DELAY_S)

    def emit_char(self, ch: str) -> None:
        if ch in DIRECT:  # plain ASCII: just type it
            self.tap(*DIRECT[ch])
            return
        seq = self.stock.get(ch)
        self.tap(ecodes.KEY_COMPOSE)
        if seq:
            for name in seq:
                self.tap(*PLAIN[name])
            return
        for code in PREFIX[1:]:
            self.tap(code)
        for d in f"{ord(ch):04d}":
            self.tap(DIGIT_KEY[d])


class Keyboard:
    def __init__(self, dev: InputDevice, out: Out) -> None:
        self.dev = dev
        self.out = out
        self.down: set[int] = set()  # keys we pressed on the virtual kbd
        self.buffer = ""
        self.alt_held = False
        self.alt_forwarded = False

    def send(self, code: int, value: int) -> None:
        if value == 1:
            self.down.add(code)
        elif value == 0:
            self.down.discard(code)
        self.out.key(code, value)

    def release_all(self) -> None:
        for code in list(self.down):
            self.out.key(code, 0)
        self.down.clear()
        self.alt_held = self.alt_forwarded = False
        self.buffer = ""

    def close(self) -> None:
        self.release_all()
        for f in (self.dev.ungrab, self.dev.close):
            try:
                f()
            except OSError:
                pass

    def handle(self, code: int, value: int) -> None:
        if code == ecodes.KEY_LEFTALT:
            if value == 1:
                self.buffer, self.alt_held, self.alt_forwarded = "", True, False
            elif value == 0:
                digits, fwd = self.buffer, self.alt_forwarded
                self.buffer, self.alt_held, self.alt_forwarded = "", False, False
                if fwd:
                    self.send(ecodes.KEY_LEFTALT, 0)
                    return
                ch = alt_to_char(digits)
                if ch:
                    print(f"alt-codes: Alt+{digits} -> {ch!r}", flush=True)
                    self.out.emit_char(ch)
                elif not digits:  # lone Alt tap: menus still work
                    self.send(ecodes.KEY_LEFTALT, 1)
                    self.send(ecodes.KEY_LEFTALT, 0)
            return  # swallow Alt autorepeat while capturing

        if self.alt_held and not self.alt_forwarded:
            if code in NUMPAD:
                if value == 1:
                    self.buffer += NUMPAD[code]
                return
            if value == 1:  # Alt+Tab, Alt+F4, …: become a real Alt chord
                self.alt_forwarded = True
                self.buffer = ""
                self.send(ecodes.KEY_LEFTALT, 1)
            elif value == 0 and code not in self.down:
                return
        self.send(code, value)


def main() -> int:
    if "--compose" in sys.argv:
        sys.stdout.write(compose_table())
        return 0
    try:
        out = Out()
    except UInputError as exc:
        print(f"alt-codes: cannot open /dev/uinput: {exc}", file=sys.stderr)
        return 1

    kbds: dict[str, Keyboard] = {}
    ignored: set[str] = set()
    last = 0.0
    while True:
        now = time.monotonic()
        if now - last >= RESCAN_S:
            last = now
            live = set(list_devices())
            ignored &= live
            for path in [p for p in kbds if p not in live]:
                kbds.pop(path).close()
                print(f"alt-codes: dropped {path}", flush=True)
            for path in live - set(kbds) - ignored:
                try:
                    dev = InputDevice(path)
                except OSError:
                    continue  # udev may not have fixed perms yet; retry
                if not is_keyboard(dev):
                    dev.close()
                    ignored.add(path)
                    continue
                try:
                    dev.grab()
                except OSError as exc:
                    print(f"alt-codes: cannot grab {path}: {exc}", flush=True)
                    dev.close()
                    continue
                kbds[path] = Keyboard(dev, out)
                print(f"alt-codes: grabbed {path} ({dev.name})", flush=True)

        fds = {k.dev.fd: p for p, k in kbds.items()}
        r, _, _ = select(list(fds) + [out.ui.fd], [], [], RESCAN_S)
        for fd in r:
            if fd == out.ui.fd:  # LED feedback from the compositor
                try:
                    for ev in out.ui.read():
                        if ev.type == ecodes.EV_LED:
                            if ev.code == ecodes.LED_CAPSL:
                                out.caps_lock = bool(ev.value)
                            for k in kbds.values():
                                try:
                                    k.dev.set_led(ev.code, ev.value)
                                except OSError:
                                    pass
                except (OSError, BlockingIOError):
                    pass
                continue
            path = fds[fd]
            kbd = kbds.get(path)
            if kbd is None:
                continue
            try:
                for ev in kbd.dev.read():
                    if ev.type == ecodes.EV_KEY:
                        kbd.handle(ev.code, ev.value)
                    elif ev.type == ecodes.EV_MSC:
                        continue
            except (OSError, BlockingIOError) as exc:
                if isinstance(exc, BlockingIOError):
                    continue
                kbds.pop(path).close()
                print(f"alt-codes: lost {path}", flush=True)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
