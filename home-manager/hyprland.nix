# Hyprland — user-level configuration.
#
# Every program here installs itself + writes its config file to
# ~/.config/<program>/ from these declarations. No GUI clicking;
# rebuild reflects exactly this file.

{ config, pkgs, inputs, ... }:

{
  # ============================================================
  #  Hyprland compositor + keybinds
  # ============================================================
  wayland.windowManager.hyprland = {
    enable  = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;

    # Hyprland 0.55 + home.stateVersion "26.05" defaults this to "lua",
    # which can't represent the classic "$mod"/"exec-once" style below
    # (invalid Lua → "emergency mode", no keybinds). Pin the classic
    # format so the settings below generate hyprland.conf as written.
    configType = "hyprlang";

    settings = {
      # Variables — referenced below in keybinds.
      "$mod"     = "SUPER";
      "$term"    = "kitty";
      "$browser" = "brave";
      "$menu"    = "wofi --show drun";

      # Two 1920x1080 screens placed side by side. The "0x0" / "1920x0"
      # is the PIXEL POSITION of each monitor's top-left corner: "0x0" is
      # the leftmost screen, "1920x0" sits immediately to its right (1920
      # px = one screen-width over). Hyprland's old "auto" placement put
      # these in the wrong order, which is why the cursor crossed to the
      # wrong side. If it's STILL reversed after rebuilding, just swap the
      # two position values (0x0 <-> 1920x0).
      monitor = [
        "DP-3,     1920x1080@60, 0x0,    1"   # Dell SE2422H — left
        "HDMI-A-1, 1920x1080@60, 1920x0, 1"   # LG FHD       — right
      ];

      # Programs to start when the Hyprland session starts.
      exec-once = [
        "hyprpaper"
        "waybar"
        "mako"
        "hyprsunset -t 3700 -T 6500 --latitude -33.9 --longitude 18.4"
      ];

      input = {
        kb_layout    = "za";
        follow_mouse = 1;
      };

      general = {
        gaps_in     = 5;
        gaps_out    = 10;
        border_size = 2;
        # BR2049-flavoured orange gradient on the active window border.
        "col.active_border"   = "rgba(ff6b00ee) rgba(ff8533ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };

      decoration = {
        rounding         = 8;
        active_opacity   = 1.0;
        inactive_opacity = 0.95;
      };

      animations.enabled = true;

      # ---- Keybinds ----
      # Format: "MODIFIER, KEY, action, args"
      # Use the Super (Windows) key as the main modifier.
      bind = [
        # Launch apps
        "$mod, Return, exec, $term"
        "$mod, R,      exec, $menu"
        "$mod, B,      exec, $browser"
        "$mod, E,      exec, thunar"     # file manager (Windows muscle memory: Win+E)

        # Window management
        "$mod,       Q, killactive"
        "$mod,       F, fullscreen"
        "$mod,       V, togglefloating"
        "$mod SHIFT, M, exit"          # quit Hyprland → back to SDDM

        # Focus
        "$mod, left,  movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up,    movefocus, u"
        "$mod, down,  movefocus, d"

        # Workspaces 1–9
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        # Move active window to workspace 1–9
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        # Screenshot region → clipboard
        '', Print, exec, grim -g "$(slurp)" - | wl-copy''

        # Monitor brightness over DDC/CI. `ddcutil detect` found the LG on
        # i2c bus 5, and the Dell on i2c bus 14.
        "$mod, F12, exec, ddcutil --bus 5 setvcp 10 + 10 && ddcutil --bus 14 setvcp 10 + 10"   # brighter
        "$mod, F11, exec, ddcutil --bus 5 setvcp 10 - 10 && ddcutil --bus 14 setvcp 10 - 10"   # dimmer
        # These fire too, if your keyboard has dedicated brightness keys:
        ", XF86MonBrightnessUp,   exec, ddcutil --bus 5 setvcp 10 + 10 && ddcutil --bus 14 setvcp 10 + 10"
        ", XF86MonBrightnessDown, exec, ddcutil --bus 5 setvcp 10 - 10 && ddcutil --bus 14 setvcp 10 - 10"
      ];

      # Mouse bindings: hold $mod + drag.
      bindm = [
        "$mod, mouse:272, movewindow"     # left-click drag = move
        "$mod, mouse:273, resizewindow"   # right-click drag = resize
      ];
    };
  };

  # ============================================================
  #  Terminal — kitty
  # ============================================================
  programs.kitty = {
    enable = true;
    settings = {
      font_family        = "JetBrainsMono Nerd Font";
      font_size          = 12;
      background_opacity = "0.9";
      cursor_shape       = "beam";
    };
  };

  # ============================================================
  #  App launcher — wofi (the "KRunner" of Hyprland)
  # ============================================================
  programs.wofi.enable = true;

  # ============================================================
  #  Status bar — waybar
  # ============================================================
  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer          = "top";
      position       = "top";
      height         = 32;
      # Francois-style layout: clock + workspaces on the left, focused-window
      # title in the centre, stats + media on the right.
      modules-left   = [ "clock" "hyprland/workspaces" ];
      modules-center = [ "hyprland/window" ];
      modules-right  = [ "mpris" "cpu" "temperature" "custom/gpu" "memory" "network" "pulseaudio" "tray" ];

      # Title of the focused window, shown on the left.
      "hyprland/window" = {
        max-length       = 50;
        separate-outputs = true;
      };

      clock = {
        format         = "{:%a %d %b  %H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      # Now-playing media — click to play/pause.
      mpris = {
        format        = "{player_icon} {dynamic}";
        format-paused = "{status_icon} {dynamic}";
        player-icons  = { default = "▶"; };
        status-icons  = { paused = "⏸"; };
        max-length    = 40;
        on-click      = "playerctl play-pause";
      };

      # System stats.
      cpu = { format = "CPU {usage}%"; interval = 2; };
      temperature = {
        format = "({temperatureC}°C)";
        critical-threshold = 80;
      };
      "custom/gpu" = {
        exec = "cat /sys/class/drm/card1/device/gpu_busy_percent";
        format = "GPU {}%";
        interval = 2;
      };
      memory = { format = "RAM {percentage}%"; interval = 5; };

      network = {
        format-wifi         = "{essid} ({signalStrength}%)";
        format-ethernet     = "wired";
        format-disconnected = "offline";
        tooltip-format      = "{ifname}: {ipaddr}";
        on-click            = "kitty -e nmtui";
      };

      tray = { spacing = 8; };

      battery = {
        format       = "{capacity}% {icon}";
        format-icons = [ "" "" "" "" "" ];
      };

      pulseaudio = {
        format       = "{volume}% {icon}";
        format-muted = "{volume}% ";
        format-icons = [ "" "" "" ];
        on-click     = "pavucontrol";
      };
    };

    # Francois's structure rendered in BR2049 orange.
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
        font-size: 14px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: rgba(17, 17, 17, 0.78);
        color: #e0c0a0;
      }

      /* Each module sits in its own rounded "pill". */
      #clock, #workspaces, #window, #mpris, #cpu, #temperature, #custom-gpu, #memory,
      #network, #pulseaudio, #tray {
        margin: 4px 3px;
        padding: 2px 10px;
        border-radius: 8px;
        background: rgba(40, 40, 40, 0.6);
      }

      #clock { color: #ff8533; font-weight: bold; }

      /* Merge CPU and Temperature into one visual box. */
      #cpu {
        margin-right: 0;
        padding-right: 4px;
        border-top-right-radius: 0;
        border-bottom-right-radius: 0;
      }
      #temperature {
        margin-left: 0;
        padding-left: 4px;
        border-top-left-radius: 0;
        border-bottom-left-radius: 0;
      }

      /* Workspaces: the active one gets the orange gradient. */
      #workspaces { padding: 2px 4px; }
      #workspaces button {
        padding: 0 8px;
        color: #888888;
        background: transparent;
        border-radius: 6px;
      }
      #workspaces button.active {
        color: #1a1a1a;
        background: linear-gradient(45deg, #ff6b00, #ff8533);
        font-weight: bold;
      }
      #workspaces button:hover {
        background: rgba(255, 133, 51, 0.25);
        color: #ffb380;
      }

      #window { color: #cccccc; }

      /* Stats: warm orange. */
      #cpu, #temperature, #custom-gpu, #memory { color: #ff8533; }
      #temperature.critical { color: #ff4444; }

      #mpris { color: #ffb380; }
      #network { color: #ff8533; }
      #network.disconnected { color: #777777; }
      #pulseaudio { color: #ffcc99; }
      #pulseaudio.muted { color: #777777; }

      /* Subtle lift when hovering. */
      #network:hover, #pulseaudio:hover, #clock:hover {
        background: rgba(255, 107, 0, 0.2);
      }
    '';
  };

  # ============================================================
  #  Notifications — mako
  # ============================================================
  services.mako.enable = true;

  # ============================================================
  #  Wallpaper
  # ============================================================
   services.hyprpaper = {
      enable = true;
      settings = {
        preload   = [ "/home/gpmare/Pictures/Bladerunner2049.png" ];
        # The part before the comma is the monitor; empty = all monitors.
        wallpaper = [
           "DP-3,/home/gpmare/Pictures/Bladerunner2049.png"
           "HDMI-A-1,/home/gpmare/Pictures/Bladerunner2049.png"
        ];
      };
    };

  # ============================================================
  #  Hyprland-adjacent CLI utilities
  # ============================================================
  home.packages = with pkgs; [
    hyprpaper
    grim          # take screenshots
    slurp         # interactively pick a region (pairs with grim)
    wl-clipboard  # `wl-copy` / `wl-paste` — Wayland clipboard CLI
    brightnessctl # control screen brightness (laptop)
    pamixer       # control volume from keyboard / scripts
    hyprsunset      # night-mode / blue-light filter (see exec-once above)
    ddcutil       # set external-monitor brightness over DDC/CI (see modules/hyprland.nix)
    playerctl     # media play/pause control (the waybar mpris module uses it)
  ];
}
