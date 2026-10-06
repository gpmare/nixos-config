"""Windows Alt+numpad codes for Linux (Plasma / Wayland).

Hold Left Alt, type digits on the numpad, release Alt:
  no leading 0  -> CP850  (Alt+130  = é)
  leading 0     -> CP1252 (Alt+0233 = é)

Grabs physical keyboards and forwards every other event through a virtual
UInput device so numpad digits are swallowed during an alt-code. Super+Alt
still appears on the virtual device for whisper-flow-hotkey.

Alt is not forwarded until a non-numpad key is pressed (Alt+Tab / Alt+F4)
or until Alt is released with no digits (menu tap). There is no timeout:
Windows alt-codes work however long you wait before the first digit.
"""

from __future__ import annotations

import subprocess
import sys
import time
from select import select

from evdev import InputDevice, UInput, UInputError, ecodes, list_devices

RESCAN_S = 5.0
SKIP_NAME = ("alt-codes", "ydotool", "ydotoold", "keyd", "whisper", "avrcp")

NUMPAD = {
    ecodes.KEY_KP0: "0",
    ecodes.KEY_KP1: "1",
    ecodes.KEY_KP2: "2",
    ecodes.KEY_KP3: "3",
    ecodes.KEY_KP4: "4",
    ecodes.KEY_KP5: "5",
    ecodes.KEY_KP6: "6",
    ecodes.KEY_KP7: "7",
    ecodes.KEY_KP8: "8",
    ecodes.KEY_KP9: "9",
}


def _key_codes(dev: InputDevice) -> set[int]:
    raw = dev.capabilities().get(ecodes.EV_KEY, [])
    codes: set[int] = set()
    for item in raw:
        if isinstance(item, (list, tuple)):
            codes.add(int(item[0]))
        else:
            codes.add(int(item))
    return codes


def is_keyboard(dev: InputDevice) -> bool:
    name = (dev.name or "").lower()
    if any(s in name for s in SKIP_NAME):
        return False
    keys = _key_codes(dev)
    # Letters + Left Alt: real typing keyboards. Skips mice, headphone
    # AVRCP remotes, and consumer-control nodes that only have KEY_ENTER.
    return ecodes.KEY_A in keys and ecodes.KEY_LEFTALT in keys


def alt_to_char(digits: str) -> str | None:
    if not digits:
        return None
    try:
        n = int(digits)
    except ValueError:
        return None
    if n < 0 or n > 255:
        return None
    codepage = "cp1252" if digits.startswith("0") else "cp850"
    try:
        return bytes([n]).decode(codepage)
    except UnicodeDecodeError:
        return None


def type_char(ch: str) -> None:
    try:
        result = subprocess.run(
            ["ydotool", "type", "--file", "-"],
            input=ch.encode("utf-8"),
            check=False,
            capture_output=True,
        )
    except OSError as exc:
        print(f"alt-codes: ydotool failed: {exc}", file=sys.stderr, flush=True)
        return
    if result.returncode != 0:
        err = (result.stderr or b"").decode("utf-8", "replace").strip()
        print(
            f"alt-codes: ydotool exit {result.returncode}: {err}",
            file=sys.stderr,
            flush=True,
        )


class Keyboard:
    def __init__(self, dev: InputDevice, ui: UInput) -> None:
        self.dev = dev
        self.ui = ui
        self.buffer = ""
        self.alt_held = False
        self.alt_forwarded = False

    def _send(self, code: int, value: int) -> None:
        self.ui.write(ecodes.EV_KEY, code, value)
        self.ui.syn()

    def close(self) -> None:
        try:
            self.dev.ungrab()
        except OSError:
            pass
        try:
            self.dev.close()
        except OSError:
            pass

    def handle(self, code: int, value: int) -> None:
        # value: 0 release, 1 press, 2 repeat
        if code == ecodes.KEY_LEFTALT:
            if value == 1:
                self.buffer = ""
                self.alt_held = True
                self.alt_forwarded = False
                return
            if value == 0:
                digits = self.buffer
                forwarded = self.alt_forwarded
                self.alt_held = False
                self.buffer = ""
                self.alt_forwarded = False
                if forwarded:
                    self._send(ecodes.KEY_LEFTALT, 0)
                    return
                ch = alt_to_char(digits)
                if ch:
                    print(f"alt-codes: Alt+{digits} -> {ch!r}", flush=True)
                    type_char(ch)
                    return
                # Alt tap / Alt+non-numpad already handled; send a tap if
                # nothing was typed so menus still open on a lone Alt.
                if not digits:
                    self._send(ecodes.KEY_LEFTALT, 1)
                    self._send(ecodes.KEY_LEFTALT, 0)
                return
            return

        capturing = self.alt_held and not self.alt_forwarded

        if capturing and code in NUMPAD:
            if value == 1:
                self.buffer += NUMPAD[code]
            return

        if capturing and value == 1:
            # Not a numpad digit: this is Alt+something (Tab, F4, …).
            self.alt_forwarded = True
            self.buffer = ""
            self._send(ecodes.KEY_LEFTALT, 1)

        self._send(code, value)


def open_keyboards(
    ui: UInput, already: set[str]
) -> tuple[dict[str, Keyboard], UInput]:
    found: dict[str, Keyboard] = {}
    for path in list_devices():
        if path in already:
            continue
        try:
            dev = InputDevice(path)
        except (OSError, PermissionError):
            continue
        if not is_keyboard(dev):
            try:
                dev.close()
            except OSError:
                pass
            continue
        try:
            dev.grab()
        except OSError as exc:
            print(f"alt-codes: cannot grab {path}: {exc}", flush=True)
            try:
                dev.close()
            except OSError:
                pass
            continue
        found[path] = Keyboard(dev, ui)
        print(f"alt-codes: grabbed {path} ({dev.name})", flush=True)
    return found, ui


def open_uinput() -> UInput:
    # Default UInput() is a full keyboard. Create it *before* grabbing so a
    # permission failure cannot leave the physical keyboard exclusive-grabbed
    # with nowhere to forward events.
    try:
        return UInput(name="alt-codes-virtual-kbd")
    except UInputError as exc:
        print(
            f"alt-codes: cannot open /dev/uinput ({exc}). "
            "Need the uinput group (SupplementaryGroups on the unit).",
            file=sys.stderr,
            flush=True,
        )
        raise SystemExit(1) from exc


def main() -> int:
    ui = open_uinput()
    devices: dict[str, Keyboard] = {}
    devices, ui = open_keyboards(ui, set())
    if not devices:
        print("alt-codes: no keyboards yet; waiting", flush=True)

    last_rescan = time.monotonic()
    while True:
        now = time.monotonic()
        if now - last_rescan >= RESCAN_S:
            last_rescan = now
            live = set(list_devices())
            for path, kbd in list(devices.items()):
                if path not in live:
                    kbd.close()
                    del devices[path]
                    print(f"alt-codes: dropped {path}", flush=True)
            fresh, ui = open_keyboards(ui, set(devices))
            devices.update(fresh)

        if not devices:
            time.sleep(1.0)
            continue

        r, _, _ = select([k.dev.fd for k in devices.values()], [], [], 1.0)
        if not r:
            continue
        fdset = set(r)
        for path, kbd in list(devices.items()):
            if kbd.dev.fd not in fdset:
                continue
            try:
                for event in kbd.dev.read():
                    if event.type != ecodes.EV_KEY:
                        ui.write(event.type, event.code, event.value)
                        if event.type == ecodes.EV_SYN:
                            ui.syn()
                        continue
                    kbd.handle(event.code, event.value)
            except (OSError, BlockingIOError):
                kbd.close()
                devices.pop(path, None)
                print(f"alt-codes: lost {path}", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
