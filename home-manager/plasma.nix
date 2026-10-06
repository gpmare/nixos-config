# Plasma-manager glue for whisper-flow.
#
# The Super+Alt hold / double-tap gesture is an evdev user daemon
# (modules/whisper-flow.nix), not a KGlobalAccel shortcut — Plasma cannot
# bind modifier-only hold/release or double-tap. This file only:
#   * enables plasma-manager without wiping existing settings
#   * keeps Super-tap as the Application Launcher
#   * ships .desktop entries so start/stop/toggle are bindable in
#     System Settings → Shortcuts as a fallback
#
# overrideConfig must stay false: true would reset unmanaged Plasma state.

{ ... }:

{
  programs.plasma = {
    enable = true;
    overrideConfig = false;
    # Super-tap stays Kickoff (Plasma default). Super+Alt hold/double-tap
    # is whisper-flow-hotkey — Plasma fires modifier-only Super on *release*
    # only if no other key was pressed, so the chord does not open Kickoff.
    # Do not declare plasmashell shortcuts here: setting one action in a
    # component can clear the rest of that component's binds.
  };

  xdg.desktopEntries = {
    whisper-flow-toggle = {
      name = "Whisper Flow Toggle";
      genericName = "Voice dictation";
      exec = "whisper-flow toggle";
      icon = "audio-input-microphone";
      categories = [ "Utility" "Audio" ];
      settings.StartupNotify = "false";
    };
    whisper-flow-start = {
      name = "Whisper Flow Start";
      exec = "whisper-flow start";
      icon = "audio-input-microphone";
      categories = [ "Utility" "Audio" ];
      settings.StartupNotify = "false";
    };
    whisper-flow-stop = {
      name = "Whisper Flow Stop";
      exec = "whisper-flow stop";
      icon = "audio-input-microphone";
      categories = [ "Utility" "Audio" ];
      settings.StartupNotify = "false";
    };
  };
}
