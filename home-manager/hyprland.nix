# Hyprland — user-level configuration.
#
# Every program here installs itself + writes its config file to
# ~/.config/<program>/ from these declarations. No GUI clicking;
# rebuild reflects exactly this file.

{ config, pkgs, inputs, ... }:

let
  hyprctl = "${inputs.hyprland.packages.${pkgs.system}.hyprland}/bin/hyprctl";

  # Runs after every hyprpaper start/restart (including after rebuilds).
  # Polls until the IPC socket is ready, then sets the wallpaper.
  setWallpaperScript = pkgs.writeShellScriptBin "set-wallpaper" ''
    until ${hyprctl} hyprpaper listactive 2>/dev/null; do sleep 0.1; done
    ${hyprctl} hyprpaper wallpaper ",/home/gpmare/Pictures/Bladerunner2049.png"
  '';

  # Astronomical sunset/sunrise daemon for Cape Town.
  # Runs as a background process started by exec-once; starts hyprsunset at
  # dusk and kills it at dawn using a simplified solar position algorithm.
  nightModeScript = pkgs.writeText "hyprsunset-auto.py" ''
    import math, datetime, time, subprocess, signal, sys

    LAT  = -33.9   # Cape Town
    LON  =  18.4
    TZ   =  2      # SAST = UTC+2
    TEMP =  3000   # Kelvin — warm night filter

    def sun_times(lat, lon, d):
        n    = d.timetuple().tm_yday
        B    = 2 * math.pi * (n - 81) / 365
        eot  = (9.87 * math.sin(2*B) - 7.53 * math.cos(B) - 1.5 * math.sin(B)) / 60
        decl = math.radians(23.45 * math.sin(B))
        cos_ha = max(-1.0, min(1.0, -math.tan(math.radians(lat)) * math.tan(decl)))
        ha   = math.degrees(math.acos(cos_ha)) / 15
        noon = 12 - lon/15 - eot
        return noon - ha + TZ, noon + ha + TZ

    def to_dt(h, d):
        mins = int(round(h * 60)) % (24 * 60)
        return datetime.datetime.combine(d, datetime.time(0)) + datetime.timedelta(minutes=mins)

    proc = None

    def start_night():
        global proc
        if proc is None or proc.poll() is not None:
            proc = subprocess.Popen(
                ["hyprsunset", "-t", str(TEMP)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )

    def stop_night():
        global proc
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except Exception:
                proc.kill()
        proc = None

    def cleanup(sig, frame):
        stop_night()
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    while True:
        now      = datetime.datetime.now()
        today    = now.date()
        tomorrow = today + datetime.timedelta(days=1)
        _, sunset_h   = sun_times(LAT, LON, today)
        sunrise_h, _  = sun_times(LAT, LON, tomorrow)
        sunset_dt  = to_dt(sunset_h,  today)
        sunrise_dt = to_dt(sunrise_h, tomorrow)
        if now < sunset_dt:
            stop_night()
            sleep_sec = (sunset_dt - now).total_seconds()
        elif now < sunrise_dt:
            start_night()
            sleep_sec = (sunrise_dt - now).total_seconds()
        else:
            stop_night()
            sleep_sec = 300
        time.sleep(max(min(sleep_sec, 3600), 30))
  '';

  # GTK3 popup with real-time brightness sliders.
  # Discovers connected outputs at runtime via wl-gammarelay D-Bus tree
  # and names them from hyprctl monitors. Adapts automatically to any
  # number of displays: 1 display → single slider; 2+ → master + individuals.
  brightnessPopupScript = pkgs.writeText "brightness-popup.py" ''
    import gi, json, re, subprocess
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk

    SVC  = "rs.wl-gammarelay"
    IFAC = "rs.wl.gammarelay"
    PROP = "Brightness"

    def discover_outputs():
        # Ask wl-gammarelay which outputs it's managing.
        try:
            tree = subprocess.check_output(
                ["busctl", "--user", "tree", SVC], stderr=subprocess.DEVNULL
            ).decode()
            paths = sorted(set(re.findall(r"/outputs/\w+", tree)))
            # /outputs itself may appear — drop it
            paths = [p for p in paths if p != "/outputs"]
        except Exception:
            return []

        # Get human-readable names from Hyprland.
        # hyprctl monitor descriptions look like "Dell Inc. DELL SE2422H GF7ZCP3";
        # the last token is a serial number — strip it.
        names = {}
        try:
            monitors = json.loads(subprocess.check_output(
                ["hyprctl", "monitors", "-j"], stderr=subprocess.DEVNULL
            ).decode())
            for m in monitors:
                key = "/outputs/" + m["name"].replace("-", "_")
                tokens = m.get("description", m["name"]).split()
                if len(tokens) > 1 and re.match(r"^[A-Z0-9]{5,}$", tokens[-1]):
                    tokens = tokens[:-1]
                names[key] = " ".join(tokens) if tokens else m["name"]
        except Exception:
            pass

        return [(p, names.get(p, p.split("/")[-1].replace("_", "-"))) for p in paths]

    def bus_get(path):
        try:
            raw = subprocess.check_output(
                ["busctl", "--user", "get-property", SVC, path, IFAC, PROP],
                stderr=subprocess.DEVNULL
            ).decode().split()[1]
            return round(float(raw) * 100)
        except Exception:
            return 100

    def bus_set(path, pct):
        subprocess.Popen(
            ["busctl", "--user", "set-property", SVC, path, IFAC, PROP,
             "d", f"{pct / 100:.4f}"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )

    class Win(Gtk.Window):
        def __init__(self):
            super().__init__(title="Brightness")
            self.set_border_width(16)
            self.set_resizable(False)
            self._busy   = False
            self._paths  = {}
            self.master  = None

            outputs = discover_outputs()

            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            self.add(vbox)

            if not outputs:
                vbox.pack_start(self._lbl("  No displays found"), False, False, 0)
                self.out_scales = []
            elif len(outputs) == 1:
                path, name = outputs[0]
                pct = bus_get(path)
                vbox.pack_start(self._lbl(f"  ☀  {name}"), False, False, 0)
                s = self._scale(pct)
                self._paths[id(s)] = path
                s.connect("value-changed", self._on_output)
                vbox.pack_start(s, False, False, 4)
                self.out_scales = [s]
            else:
                out_pcts   = [bus_get(p) for p, _ in outputs]
                master_pct = sum(out_pcts) // len(out_pcts)

                vbox.pack_start(self._lbl("  ☀  All displays"), False, False, 0)
                self.master = self._scale(master_pct)
                self.master.connect("value-changed", self._on_master)
                vbox.pack_start(self.master, False, False, 4)

                vbox.pack_start(
                    Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL),
                    False, False, 8
                )

                self.out_scales = []
                for (path, name), pct in zip(outputs, out_pcts):
                    vbox.pack_start(self._lbl(f"  {name}"), False, False, 0)
                    s = self._scale(pct)
                    self._paths[id(s)] = path
                    s.connect("value-changed", self._on_output)
                    vbox.pack_start(s, False, False, 4)
                    self.out_scales.append(s)

            vbox.pack_start(
                Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL),
                False, False, 8
            )
            btn = Gtk.Button(label="Close")
            btn.connect("clicked", lambda _: self.destroy())
            vbox.pack_start(btn, False, False, 0)

            self.connect("destroy", Gtk.main_quit)
            self.show_all()

        def _lbl(self, text):
            return Gtk.Label(label=text, xalign=0.0)

        def _scale(self, value):
            adj = Gtk.Adjustment(
                value=value, lower=10, upper=100,
                step_increment=5, page_increment=10
            )
            s = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
            s.set_digits(0)
            s.set_value_pos(Gtk.PositionType.RIGHT)
            s.set_size_request(280, -1)
            return s

        def _on_master(self, scale):
            if self._busy:
                return
            pct = round(scale.get_value())
            self._busy = True
            for s in self.out_scales:
                s.set_value(pct)
                bus_set(self._paths[id(s)], pct)
            self._busy = False

        def _on_output(self, scale):
            if self._busy:
                return
            bus_set(self._paths[id(scale)], round(scale.get_value()))
            if self.master is not None:
                avg = sum(round(s.get_value()) for s in self.out_scales) // len(self.out_scales)
                self._busy = True
                self.master.set_value(avg)
                self._busy = False

    Win()
    Gtk.main()
  '';
in
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
        "waybar"
        "mako"
        "wl-gammarelay-rs"    # brightness daemon — exposes D-Bus interface for brightness-* scripts
        "hyprsunset-auto"     # sunset/sunrise scheduler — starts hyprsunset at dusk, kills at dawn
        "qpwgraph -a ${config.home.homeDirectory}/Music/patchbay.qpwgraph"  # restore audio/MIDI routing
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

        # Software brightness via wl-gammarelay — works on both monitors regardless of DDC/CI.
        "$mod, F12, exec, brightness-step 10"
        "$mod, F11, exec, brightness-step -10"
        ", XF86MonBrightnessUp,   exec, brightness-step 10"
        ", XF86MonBrightnessDown, exec, brightness-step -10"
      ];

      # Mouse bindings: hold $mod + drag.
      bindm = [
        "$mod, mouse:272, movewindow"     # left-click drag = move
        "$mod, mouse:273, resizewindow"   # right-click drag = resize
      ];

      # Float the yad brightness-popup near the right end of the top bar.
      # Hyprland 0.55 new windowrule syntax: space-separated, no comma.
      windowrule = [
        "float    title:^(Brightness)$"
        "move 100%-310 38 title:^(Brightness)$"
        "no_anim  title:^(Brightness)$"
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
      font_size          = 13;
      background_opacity = "0.92";
      cursor_shape       = "beam";
      cursor_blink_interval = "0.6";
      window_padding_width  = 10;
      confirm_os_window_close = 0;

      # Tab bar
      tab_bar_style            = "powerline";
      tab_powerline_style      = "slanted";
      active_tab_foreground    = "#0d0d0d";
      active_tab_background    = "#ff6b00";
      inactive_tab_foreground  = "#808080";
      inactive_tab_background  = "#1a1a1a";
      tab_bar_background       = "#0d0d0d";

      # Blade Runner 2049 — deep black, amber text, orange accents
      background            = "#0d0d0d";
      foreground            = "#e0c0a0";
      selection_background  = "#2a2a2a";
      selection_foreground  = "#ff8533";
      cursor                = "#ff6b00";
      cursor_text_color     = "#0d0d0d";
      url_color             = "#ff8533";

      # 16 terminal colours — warm/dark palette
      color0  = "#1a1a1a"; color8  = "#404040"; # black
      color1  = "#cc4444"; color9  = "#ff5555"; # red
      color2  = "#7a9955"; color10 = "#a0c070"; # green
      color3  = "#d4a040"; color11 = "#ffcc66"; # yellow/amber
      color4  = "#5577aa"; color12 = "#6699cc"; # blue
      color5  = "#aa6688"; color13 = "#cc88aa"; # magenta
      color6  = "#4499aa"; color14 = "#66bbcc"; # cyan
      color7  = "#c0a080"; color15 = "#e0c0a0"; # white (warm)
    };
  };

  # ============================================================
  #  App launcher — wofi (the "KRunner" of Hyprland)
  # ============================================================
  programs.wofi = {
    enable = true;
    settings = {
      width           = 580;
      height          = 380;
      prompt          = "";
      insensitive     = true;
      allow_markup    = true;
      hide_scroll     = true;
      dynamic_lines   = false;
    };
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
      }

      window {
        background-color: rgba(13, 13, 13, 0.94);
        border:           1px solid rgba(255, 107, 0, 0.45);
        border-radius:    10px;
      }

      #input {
        background-color: rgba(26, 26, 26, 0.9);
        color:            #e0c0a0;
        border:           1px solid rgba(255, 107, 0, 0.25);
        border-radius:    6px;
        padding:          8px 12px;
        margin:           10px 10px 4px 10px;
        caret-color:      #ff6b00;
      }

      #input:focus {
        border-color: #ff6b00;
        color:        #ff8533;
      }

      #inner-box { background-color: transparent; }
      #outer-box { padding: 4px 6px 8px 6px; }

      #entry {
        border-radius: 6px;
        padding:       6px 10px;
        margin:        2px 0;
      }

      #entry:selected {
        background-color: rgba(255, 107, 0, 0.15);
        border:           1px solid rgba(255, 107, 0, 0.5);
      }

      #text {
        color: #c0a080;
      }

      #entry:selected #text {
        color: #ff8533;
      }

      #img {
        margin-right: 8px;
      }
    '';
  };

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
      modules-right  = [ "mpris" "cpu" "temperature" "custom/gpu" "memory" "network" "pulseaudio" "custom/brightness" "tray" ];

      # Title of the focused window, shown on the left.
      "hyprland/window" = {
        max-length       = 50;
        separate-outputs = true;
        rewrite          = { "A day without Hyprland is a day wasted" = ""; };
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
        hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
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

      # Software brightness widget — scroll to nudge, click for popup slider.
      "custom/brightness" = {
        exec             = "brightness-get";
        "on-scroll-up"   = "brightness-step 5";
        "on-scroll-down" = "brightness-step -5";
        "on-click"       = "brightness-popup";
        interval         = 2;
        tooltip          = false;
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
      #network, #pulseaudio, #custom-brightness, #tray {
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
      #custom-brightness { color: #ffdd99; }

      /* Subtle lift when hovering. */
      #network:hover, #pulseaudio:hover, #custom-brightness:hover, #clock:hover {
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
  # hyprpaper 0.8.4 ignores its config file (no config-read messages even with
  # --verbose). Wallpaper must be set via IPC. ExecStartPost fires on every
  # start and restart (including after rebuilds), so the wallpaper survives.
  services.hyprpaper.enable = true;
  systemd.user.services.hyprpaper.Service.ExecStartPost =
    "${setWallpaperScript}/bin/set-wallpaper";

  # ============================================================
  #  Hyprland-adjacent CLI utilities
  # ============================================================
  home.packages = with pkgs; [
    setWallpaperScript
    grim          # take screenshots
    slurp         # interactively pick a region (pairs with grim)
    wl-clipboard  # `wl-copy` / `wl-paste` — Wayland clipboard CLI
    brightnessctl # control screen brightness (laptop)
    pamixer       # control volume from keyboard / scripts
    hyprsunset    # night-mode via CTM — started at sunset by hyprsunset-auto
    wl-gammarelay-rs # software brightness via gamma LUT, D-Bus controlled
    gtk3          # needed by the brightness-popup Python GTK script
    ddcutil       # DDC/CI brightness (LG only; Dell needs an active DP→HDMI adapter)
    playerctl     # media play/pause control (the waybar mpris module uses it)

    # ---- brightness-* wrappers for wl-gammarelay ----
    # brightness-get   → waybar exec, prints "☀ 80%"
    # brightness-step  → keybinds and waybar scroll, takes ±integer
    # brightness-popup → waybar click, opens a yad slider window
    (writeShellScriptBin "brightness-get" ''
      raw=$(busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Brightness 2>/dev/null | awk '{print $2}')
      [ -z "$raw" ] && printf "☀ 100%%\n" && exit 0
      awk "BEGIN {printf \"☀ %.0f%%\\n\", $raw * 100}"
    '')
    (writeShellScriptBin "brightness-step" ''
      raw=$(busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Brightness 2>/dev/null | awk '{print $2}')
      [ -z "$raw" ] && exit 0
      current=$(awk "BEGIN {printf \"%.0f\", $raw * 100}")
      new=$(( current + $1 ))
      [ "$new" -lt 10 ] && new=10
      [ "$new" -gt 100 ] && new=100
      busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d \
        "$(awk "BEGIN {printf \"%.4f\", $new / 100}")"
    '')
    (writeShellScriptBin "brightness-popup" ''
      export GI_TYPELIB_PATH="${pkgs.gtk3}/lib/girepository-1.0:${pkgs.glib.out}/lib/girepository-1.0:${pkgs.pango.out}/lib/girepository-1.0:${pkgs.at-spi2-core}/lib/girepository-1.0:${pkgs.gdk-pixbuf}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0:${pkgs.harfbuzz}/lib/girepository-1.0"
      exec ${pkgs.python3.withPackages (p: [ p.pygobject3 ])}/bin/python3 \
        ${brightnessPopupScript}
    '')

    # ---- sunset/sunrise scheduler ----
    (writeShellScriptBin "hyprsunset-auto" ''
      exec ${pkgs.python3}/bin/python3 ${nightModeScript}
    '')
  ];
}
