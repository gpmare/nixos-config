"""Super+Alt chord watcher for whisper-flow.

Hold Super+Alt  → start listening; release → stop (push-to-talk).
Double-tap Super+Alt → toggle locked listening (second double-tap stops).

Does not grab devices, so Super-alone and Alt-alone still reach the compositor.
"""

from __future__ import annotations

import subprocess
import sys
import threading
import time
from select import select

from evdev import InputDevice, ecodes, list_devices

HOLD_S = 0.220
DOUBLE_TAP_S = 0.350
RESCAN_S = 5.0

META = {ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA}
ALT = {ecodes.KEY_LEFTALT, ecodes.KEY_RIGHTALT}
WATCH = META | ALT


class ChordWatcher:
    def __init__(self) -> None:
        self.meta = 0
        self.alt = 0
        self.both_since: float | None = None
        self.hold_timer: threading.Timer | None = None
        self.in_ptt = False
        self.locked = False
        self.last_tap: float | None = None
        self.ignore_until_release = False
        self.lock = threading.Lock()

    def both(self) -> bool:
        return self.meta > 0 and self.alt > 0

    def _cancel_hold(self) -> None:
        if self.hold_timer is not None:
            self.hold_timer.cancel()
            self.hold_timer = None

    def _run(self, arg: str) -> None:
        try:
            subprocess.Popen(
                ["whisper-flow", arg],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError as exc:
            print(f"whisper-flow-hotkey: failed to spawn whisper-flow {arg}: {exc}", file=sys.stderr)

    def _on_hold(self) -> None:
        with self.lock:
            self.hold_timer = None
            if not self.both() or self.locked or self.ignore_until_release:
                return
            self.in_ptt = True
            self.last_tap = None
        print("whisper-flow-hotkey: PTT start", flush=True)
        self._run("start")

    def handle(self, code: int, pressed: bool) -> None:
        with self.lock:
            if code in META:
                self.meta = self.meta + 1 if pressed else max(0, self.meta - 1)
            elif code in ALT:
                self.alt = self.alt + 1 if pressed else max(0, self.alt - 1)
            else:
                return

            now = time.monotonic()

            if self.both():
                if self.both_since is not None:
                    return
                self.both_since = now
                if (
                    self.last_tap is not None
                    and (now - self.last_tap) <= DOUBLE_TAP_S
                ):
                    self.last_tap = None
                    self._cancel_hold()
                    self.ignore_until_release = True
                    self.in_ptt = False
                    if self.locked:
                        self.locked = False
                        print("whisper-flow-hotkey: toggle off", flush=True)
                        cmd = "stop"
                    else:
                        self.locked = True
                        print("whisper-flow-hotkey: toggle on", flush=True)
                        cmd = "start"
                    # spawn outside? we still hold the lock. spawn is fast.
                    self._run(cmd)
                    return

                self._cancel_hold()
                self.hold_timer = threading.Timer(HOLD_S, self._on_hold)
                self.hold_timer.daemon = True
                self.hold_timer.start()
                return

            # Chord broken.
            had_chord = self.both_since is not None
            started_at = self.both_since
            self.both_since = None
            self._cancel_hold()

            if self.ignore_until_release:
                if self.meta == 0 and self.alt == 0:
                    self.ignore_until_release = False
                return

            if self.in_ptt:
                self.in_ptt = False
                print("whisper-flow-hotkey: PTT stop", flush=True)
                self._run("stop")
                return

            if (
                had_chord
                and started_at is not None
                and not self.locked
                and (now - started_at) < HOLD_S
            ):
                self.last_tap = now


def _key_codes(dev: InputDevice) -> set[int]:
    raw = dev.capabilities().get(ecodes.EV_KEY, [])
    codes: set[int] = set()
    for item in raw:
        if isinstance(item, (list, tuple)):
            codes.add(int(item[0]))
        else:
            codes.add(int(item))
    return codes


def open_keyboards() -> dict[str, InputDevice]:
    devices: dict[str, InputDevice] = {}
    denied = 0
    for path in list_devices():
        try:
            dev = InputDevice(path)
            if WATCH & _key_codes(dev):
                devices[path] = dev
            else:
                dev.close()
        except PermissionError:
            denied += 1
        except OSError:
            continue
    if not devices and denied:
        print(
            f"whisper-flow-hotkey: {denied} input devices not readable "
            "(need input group)",
            flush=True,
        )
    return devices


def main() -> int:
    watcher = ChordWatcher()
    devices = open_keyboards()
    if not devices:
        print("whisper-flow-hotkey: no keyboards yet; waiting", flush=True)
    else:
        print(
            "whisper-flow-hotkey: watching "
            + ", ".join(sorted(devices)),
            flush=True,
        )

    last_rescan = time.monotonic()
    while True:
        now = time.monotonic()
        if now - last_rescan >= RESCAN_S:
            last_rescan = now
            fresh = open_keyboards()
            for path, dev in list(devices.items()):
                if path not in fresh:
                    try:
                        dev.close()
                    except OSError:
                        pass
                    del devices[path]
                    print(f"whisper-flow-hotkey: dropped {path}", flush=True)
            for path, dev in fresh.items():
                if path not in devices:
                    devices[path] = dev
                    print(f"whisper-flow-hotkey: added {path}", flush=True)
                else:
                    try:
                        dev.close()
                    except OSError:
                        pass

        if not devices:
            time.sleep(1.0)
            continue

        r, _, _ = select([dev.fd for dev in devices.values()], [], [], 1.0)
        if not r:
            continue
        fdset = set(r)
        for path, dev in list(devices.items()):
            if dev.fd not in fdset:
                continue
            try:
                for event in dev.read():
                    if event.type != ecodes.EV_KEY:
                        continue
                    if event.code not in WATCH:
                        continue
                    # 0 = release, 1 = press, 2 = repeat — ignore repeat
                    if event.value not in (0, 1):
                        continue
                    watcher.handle(event.code, event.value == 1)
            except (OSError, BlockingIOError):
                try:
                    dev.close()
                except OSError:
                    pass
                devices.pop(path, None)
                print(f"whisper-flow-hotkey: lost {path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
