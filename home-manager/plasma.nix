# Plasma-manager settings.
#
#   * enables plasma-manager without wiping existing settings
#   * keeps Super-tap as the Application Launcher
#
# overrideConfig must stay false: true would reset unmanaged Plasma state.

{ ... }:

{
  programs.plasma = {
    enable = true;
    overrideConfig = false;

    # AC: never DPMS-off the display (Grok Bot drops its remote-exec helper
    # ~4 min after the display turns off), but dim after 5 min idle to limit
    # heat/burn-in. Plasma 6 dims to a fixed fraction of current brightness;
    # there is no dim-level key. Battery/LowBattery stay at Plasma defaults.
    powerdevil.AC = {
      turnOffDisplay.idleTimeout = "never";
      dimDisplay = { enable = true; idleTimeout = 300; };
    };
    # Pitch-black desktop and lock screen ("switched-off screen" look).
    workspace.wallpaperPlainColor = "0,0,0";
    kscreenlocker.appearance.wallpaperPlainColor = "0,0,0";

    # Live CPU / RAM / GPU % on the existing panel (waybar-style). The panel
    # itself is unmanaged (declaring `panels` would wipe it), so this script
    # only appends three text-only System Monitor widgets next to the tray
    # if they are not already there. gpu/all/usage works on Intel and AMD.
    startup.desktopScript."sysmon_panel_widgets" = {
      text = builtins.readFile ./plasma-sysmon.js;
      priority = 8;
    };

    # Super-tap stays Kickoff (Plasma default).
    # Do not declare plasmashell shortcuts here: setting one action in a
    # component can clear the rest of that component's binds.
  };
}
