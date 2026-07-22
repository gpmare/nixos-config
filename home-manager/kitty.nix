# Kitty terminal — Apple-like light/dark themes, compact type, theme toggle.
# System package is in modules/packages.nix.

{ pkgs, lib, config, ... }:

let
  ansiCommon = ''
    color1  #c41a16
    color2  #28c840
    color3  #c7c329
    color4  #0a84ff
    color5  #bf5af2
    color6  #5ac8fa
    color9  #ff3b30
    color10 #32d74b
    color11 #ffd60a
    color12 #409cff
    color13 #da8fff
    color14 #70d7ff
  '';

  lightTheme = ''
    background #fcfcf8
    foreground #1d1d1f
    cursor #007aff
    cursor_text_color #fcfcf8
    selection_background #b3d7ff
    selection_foreground #1d1d1f
    url_color #0066cc
    color0  #000000
    color7  #e5e5e5
    color8  #666666
    color15 #ffffff
    ${ansiCommon}
    active_tab_foreground #1d1d1f
    active_tab_background #fcfcf8
    inactive_tab_foreground #6e6e73
    inactive_tab_background #e8e8ed
    tab_bar_background #e8e8ed
    active_border_color #c6c6c8
    inactive_border_color #e5e5ea
  '';

  darkTheme = ''
    background #1c1c1e
    foreground #f5f5f7
    cursor #0a84ff
    cursor_text_color #1c1c1e
    selection_background #3a3a3c
    selection_foreground #f5f5f7
    url_color #64d2ff
    color0  #1c1c1e
    color7  #f5f5f7
    color8  #636366
    color15 #ffffff
    ${ansiCommon}
    active_tab_foreground #1c1c1e
    active_tab_background #f5f5f7
    inactive_tab_foreground #aeaeb2
    inactive_tab_background #2c2c2e
    tab_bar_background #2c2c2e
    active_border_color #48484a
    inactive_border_color #2c2c2e
  '';

  # Kitten: switch light ↔ dark for every open window.
  toggleKitten = ''
    from __future__ import annotations

    import os
    from pathlib import Path
    from typing import List

    from kitty.boss import Boss
    from kittens.tui.handler import result_handler

    CONF = Path(os.path.expanduser("~/.config/kitty"))
    STATE = CONF / "theme-state"
    LIGHT = CONF / "themes" / "light.conf"
    DARK = CONF / "themes" / "dark.conf"


    def current() -> str:
        try:
            return (STATE.read_text().strip() or "light")
        except OSError:
            return "light"


    def apply(boss: Boss, name: str) -> None:
        path = LIGHT if name == "light" else DARK
        w = next(iter(boss.all_windows), None)
        boss.call_remote_control(
            w,
            ("set-colors", "--configured", "--all", str(path)),
        )
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(name + "\n")
        # Redraw tab bars so the ☀/☾ label updates
        for tm in boss.all_tab_managers:
            tm.mark_tab_bar_dirty()


    def main(args: List[str]) -> str:
        return ""


    @result_handler(no_ui=True)
    def handle_result(
        args: List[str], answer: str, target_window_id: int, boss: Boss
    ) -> None:
        nxt = "dark" if current() == "light" else "light"
        if len(args) > 1 and args[1] in ("light", "dark"):
            nxt = args[1]
        apply(boss, nxt)
  '';

  # Custom tab bar: normal titles + light/dark control on the far right.
  # Click the right-hand pill (or press Ctrl+Shift+L) to toggle.
  tabBar = ''
    from __future__ import annotations

    import os
    from pathlib import Path

    from kitty.fast_data_types import Screen, get_options
    from kitty.tab_bar import (
        DrawData,
        ExtraData,
        TabBarData,
        as_rgb,
        draw_title,
    )
    from kitty.utils import color_as_int

    STATE = Path(os.path.expanduser("~/.config/kitty/theme-state"))

    # Global so handle_click can know where the pill was drawn
    _PILL_START = 0


    def _theme() -> str:
        try:
            return STATE.read_text().strip() or "light"
        except OSError:
            return "light"


    def draw_tab(
        draw_data: DrawData,
        screen: Screen,
        tab: TabBarData,
        before: int,
        max_tab_length: int,
        index: int,
        is_last: bool,
        extra_data: ExtraData,
    ) -> int:
        global _PILL_START
        end = draw_title(draw_data, screen, tab, index)
        if not is_last:
            return screen.cursor.x

        theme = _theme()
        # Show what clicking will switch TO
        icon = "  ☾  " if theme == "light" else "  ☀  "
        cells_left = screen.columns - screen.cursor.x - len(icon)
        if cells_left > 0:
            screen.draw(" " * cells_left)

        _PILL_START = screen.cursor.x
        opts = get_options()
        if theme == "light":
            screen.cursor.fg = as_rgb(color_as_int(opts.color4))
            screen.cursor.bg = as_rgb(0xE8E8ED)
        else:
            screen.cursor.fg = as_rgb(color_as_int(opts.color11))
            screen.cursor.bg = as_rgb(0x2C2C2E)
        screen.draw(icon)
        return screen.cursor.x


    def handle_click(button: int, modifiers: int, cell_x: int, cell_y: int) -> bool:
        """Left-click on the right-hand ☀/☾ pill → toggle theme."""
        # button 1 = left
        if button != 1:
            return False
        if cell_x < _PILL_START:
            return False
        # Run the toggle kitten in this OS window
        from kitty.boss import get_boss

        boss = get_boss()
        if boss is None:
            return False
        boss.run_kitten("toggle_theme.py")
        return True
  '';
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      # Was 14; −15% ≈ 11.9 so more rows fit.
      size = 11.9;
    };

    settings = {
      window_padding_width = "10 12";
      window_margin_width = 0;
      hide_window_decorations = "no";
      confirm_os_window_close = 0;
      remember_window_size = "yes";
      initial_window_width = "100c";
      initial_window_height = "30c";
      placement_strategy = "center";

      # Default light palette (live toggle overrides via set-colors)
      background = "#fcfcf8";
      foreground = "#1d1d1f";
      cursor = "#007aff";
      cursor_text_color = "#fcfcf8";
      selection_background = "#b3d7ff";
      selection_foreground = "#1d1d1f";
      url_color = "#0066cc";
      color0 = "#000000";
      color1 = "#c41a16";
      color2 = "#28c840";
      color3 = "#c7c329";
      color4 = "#0a84ff";
      color5 = "#bf5af2";
      color6 = "#5ac8fa";
      color7 = "#e5e5e5";
      color8 = "#666666";
      color9 = "#ff3b30";
      color10 = "#32d74b";
      color11 = "#ffd60a";
      color12 = "#409cff";
      color13 = "#da8fff";
      color14 = "#70d7ff";
      color15 = "#ffffff";

      cursor_shape = "beam";
      cursor_beam_thickness = "1.5";
      cursor_blink_interval = "0.75";
      shell_integration = "enabled";

      disable_ligatures = "cursor";
      modify_font = "cell_height 115%";
      adjust_line_height = 1;
      text_composition_strategy = "platform";

      enable_audio_bell = "no";
      visual_bell_duration = "0.0";
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";
      mouse_hide_wait = "2.0";

      # Always-on top bar so the ☀/☾ control stays visible top-right.
      tab_bar_edge = "top";
      tab_bar_style = "custom";
      tab_bar_min_tabs = 1;
      tab_bar_align = "left";
      tab_title_template = "{title}";
      active_tab_font_style = "bold";
      active_tab_foreground = "#1d1d1f";
      active_tab_background = "#fcfcf8";
      inactive_tab_foreground = "#6e6e73";
      inactive_tab_background = "#e8e8ed";
      tab_bar_background = "#e8e8ed";

      background_opacity = "1.0";
      scrollback_lines = 20000;
      wheel_scroll_multiplier = 3.5;
      underline_hyperlinks = "always";

      # Live recolour from the toggle kitten
      allow_remote_control = "yes";
      listen_on = "unix:${config.home.homeDirectory}/.cache/kitty/ctl.sock";
    };

    keybindings = {
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+w" = "close_tab";
      "ctrl+equal" = "change_font_size all +1.0";
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+0" = "change_font_size all 0";
      # Light ↔ dark (also: click ☀/☾ on the top-right of the tab bar)
      "ctrl+shift+l" = "kitten toggle_theme.py";
    };

    extraConfig = ''
      inactive_text_alpha 0.72
      draw_minimal_borders yes
      window_border_width 0.5pt
      active_border_color #c6c6c8
      inactive_border_color #e5e5ea
    '';
  };

  xdg.configFile."kitty/themes/light.conf".text = lightTheme;
  xdg.configFile."kitty/themes/dark.conf".text = darkTheme;
  xdg.configFile."kitty/toggle_theme.py".text = toggleKitten;
  xdg.configFile."kitty/tab_bar.py".text = tabBar;

  home.sessionVariables.TERMINAL = "kitty";
  xdg.configFile."xdg-terminals.list".text = ''
    kitty.desktop
  '';

  home.activation.kittyThemeSetup =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.cache/kitty" "$HOME/.config/kitty"
      # Don't clobber user choice on every rebuild
      if [ ! -f "$HOME/.config/kitty/theme-state" ]; then
        echo light > "$HOME/.config/kitty/theme-state"
      fi
    '';

  home.activation.setKittyAsPlasmaTerminal =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kdeglobals --group General --key TerminalApplication kitty
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kdeglobals --group General --key TerminalService kitty.desktop
    '';
}
