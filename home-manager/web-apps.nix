# Lightweight "desktop apps" for sites with no good native NixOS client.
# Brave is the default browser; --app= opens a frameless PWA-style window.

{ ... }:

{
  xdg.desktopEntries.google-calendar = {
    name = "Google Calendar";
    genericName = "Calendar";
    comment = "Google Calendar (web app)";
    exec = "brave --app=https://calendar.google.com/calendar --class=GoogleCalendar --name=GoogleCalendar";
    icon = "x-office-calendar";
    categories = [ "Office" "Calendar" ];
    startupNotify = true;
    settings.StartupWMClass = "GoogleCalendar";
  };

  # Replaces pear-desktop (Electron wrapper was erroring on missing packages).
  xdg.desktopEntries.youtube-music = {
    name = "YouTube Music";
    genericName = "Music";
    comment = "YouTube Music (web app)";
    exec = "brave --app=https://music.youtube.com --class=YouTubeMusic --name=YouTubeMusic";
    icon = "multimedia-audio-player";
    categories = [ "AudioVideo" "Audio" "Player" ];
    startupNotify = true;
    settings.StartupWMClass = "YouTubeMusic";
  };

  # Replaces karere (Gtk client was slow/glitchy). WhatsApp Web is the
  # reliable Linux option; no nixpkgs client is clearly better.
  xdg.desktopEntries.whatsapp = {
    name = "WhatsApp";
    genericName = "Messenger";
    comment = "WhatsApp Web (web app)";
    exec = "brave --app=https://web.whatsapp.com --class=WhatsApp --name=WhatsApp";
    icon = "user-available";
    categories = [ "Network" "InstantMessaging" ];
    startupNotify = true;
    settings.StartupWMClass = "WhatsApp";
  };
}
