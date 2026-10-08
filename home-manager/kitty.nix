# Kitty terminal — Gruvbox Dark Medium, matching francoisrob/dotfiles.
# System package is in modules/packages.nix.
# Palette: https://github.com/morhetz/gruvbox (bg0 #282828, fg1 #ebdbb2)

{ pkgs, lib, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };

    settings = {
      # Gruvbox Dark Medium
      background = "#282828";
      foreground = "#ebdbb2";
      selection_background = "#504945";
      selection_foreground = "#ebdbb2";
      cursor = "#ebdbb2";
      cursor_text_color = "#282828";
      url_color = "#83a598";
      active_border_color = "#8ec07c";
      inactive_border_color = "#504945";
      bell_border_color = "#fe8019";
      active_tab_background = "#8ec07c";
      active_tab_foreground = "#282828";
      inactive_tab_background = "#3c3836";
      inactive_tab_foreground = "#a89984";
      mark1_foreground = "#282828";
      mark1_background = "#8ec07c";
      mark2_foreground = "#282828";
      mark2_background = "#fabd2f";
      mark3_foreground = "#282828";
      mark3_background = "#d3869b";
      color0 = "#282828";
      color8 = "#928374";
      color1 = "#cc241d";
      color9 = "#fb4934";
      color2 = "#98971a";
      color10 = "#b8bb26";
      color3 = "#d79921";
      color11 = "#fabd2f";
      color4 = "#458588";
      color12 = "#83a598";
      color5 = "#b16286";
      color13 = "#d3869b";
      color6 = "#689d6a";
      color14 = "#8ec07c";
      color7 = "#a89984";
      color15 = "#ebdbb2";

      term = "xterm-256color";
      allow_remote_control = "yes";
      placement_strategy = "center";
      hide_window_decorations = "yes";
      resize_in_steps = "yes";
      disable_ligatures = "never";
      remember_window_size = "no";
      initial_window_width = "800";
      initial_window_height = "600";
      window_padding_width = 0;
      window_margin_width = 0;
      draw_minimal_borders = "no";
      background_opacity = "0.8";
      mouse_hide_wait = "1.0";
      copy_on_select = "yes";
      cursor_shape = "beam";
      cursor_beam_thickness = "1.5";
      shell_integration = "enabled no-cursor";
      cursor_trail = 1;
      cursor_trail_decay = "0.1 0.2";
      cursor_trail_start_threshold = 2;
      scrollback_lines = 20000;
      url_style = "curly";
      open_url_with = "default";
      detect_urls = "yes";
      strip_trailing_spaces = "smart";
      default_pointer_shape = "beam";
      pointer_shape_when_dragging = "beam";
      tab_bar_margin_width = "1.0";
      tab_bar_margin_height = "1.0 1.0";
      confirm_os_window_close = 0;
    };

    keybindings = {
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+w" = "close_tab";
      "ctrl+equal" = "change_font_size all +1.0";
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+0" = "change_font_size all 0";
    };

    extraConfig = ''
      font_family      family='JetBrainsMono Nerd Font' features='+ss19 +calt +ss01 +ss02 +zero aalt=0'
      bold_font        family='JetBrainsMono Nerd Font' features='+ss19 +calt +ss01 +ss02 +zero aalt=0'
      italic_font      family='JetBrainsMono Nerd Font' features='+ss19 +calt +ss01 +ss02 +zero aalt=0'
      bold_italic_font family='JetBrainsMono Nerd Font' features='+ss19 +calt +ss01 +ss02 +zero aalt=0'
      env THEME_FLAVOUR=Gruvbox-Dark-Medium
    '';
  };

  home.sessionVariables.TERMINAL = "kitty";
  xdg.configFile."xdg-terminals.list".text = ''
    kitty.desktop
  '';

  # Hidden launcher so Plasma can bind Super+T (Win+T) to Kitty.
  xdg.desktopEntries.launch-kitty = {
    name = "Kitty Terminal";
    exec = "kitty";
    icon = "kitty";
    terminal = false;
    noDisplay = true;
    settings = {
      "X-KDE-GlobalAccel-CommandShortcut" = "true";
      "X-KDE-Shortcuts" = "Meta+T";
    };
  };

  home.activation.setKittyAsPlasmaTerminal =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kdeglobals --group General --key TerminalApplication kitty
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
        --file kdeglobals --group General --key TerminalService kitty.desktop

      # Super+T is KWin's tiles editor by default — free it for Kitty.
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --notify \
        --file kglobalshortcutsrc --group kwin --key "Edit Tiles" \
        "none,Meta+T,Toggle Tiles Editor"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --notify \
        --file kglobalshortcutsrc --group launch-kitty.desktop \
        --key _k_friendly_name "Kitty Terminal"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --notify \
        --file kglobalshortcutsrc --group launch-kitty.desktop \
        --key _launch "Meta+T,none,Kitty Terminal"

      ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 >/dev/null 2>&1 || true
    '';
}
