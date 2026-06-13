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

      monitor = ",preferred,auto,1";

      # Programs to start when the Hyprland session starts.
      exec-once = [
        "waybar"
        "mako"
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
      modules-left   = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right  = [ "pulseaudio" "network" "battery" "tray" ];

      clock = {
        format = "{:%H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      battery = {
        format       = "{capacity}% {icon}";
        format-icons = [ "" "" "" "" "" ];
      };

      pulseaudio = {
        format       = "{volume}% {icon}";
        format-icons = [ "" "" "" ];
        on-click     = "pavucontrol";
      };
    };

    # BR2049-tinted CSS: dark bg with orange foreground.
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }
      window#waybar {
        background: rgba(0, 0, 0, 0.7);
        color: #ff8533;
        border-bottom: 2px solid #ff6b00;
      }
      #workspaces button.active {
        color: #ff6b00;
        background: rgba(255, 107, 0, 0.15);
      }
    '';
  };

  # ============================================================
  #  Notifications — mako
  # ============================================================
  services.mako.enable = true;

  # ============================================================
  #  Hyprland-adjacent CLI utilities
  # ============================================================
  home.packages = with pkgs; [
    grim          # take screenshots
    slurp         # interactively pick a region (pairs with grim)
    wl-clipboard  # `wl-copy` / `wl-paste` — Wayland clipboard CLI
    brightnessctl # control screen brightness (laptop)
    pamixer       # control volume from keyboard / scripts
  ];
}
