# Host: nucbox — GMKtec NucBox K8 Plus mini PC (Ryzen 7 8845HS, Radeon 780M).
# Always-on desktop: also runs the Hermes gateway container.
# Shared config: ../common.nix. Hardware: ./hardware-configuration.nix.

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix

    # Hermes Agent gateway (Docker). One gateway only: a second copy on
    # another machine would log into the same chat bots twice.
    ../../modules/hermes.nix

    # Learning-platform autograder (rootless podman sandbox).
    ../../modules/learn-grader.nix
  ];

  # ============================================================
  #  LUKS-encrypted swap partition (root LUKS is in hardware-configuration.nix)
  # ============================================================
  boot.initrd.luks.devices."luks-5f8e2b15-11a6-4511-851c-2110170d173a".device =
    "/dev/disk/by-uuid/5f8e2b15-11a6-4511-851c-2110170d173a";

  # ============================================================
  #  Ollama GPU — AMD 780M (Phoenix / gfx1103)
  # ============================================================
  # whisper-flow.nix enables ollama on CPU by default. This host has a
  # Radeon 780M that ROCm does not detect as a supported gfx, so override
  # the LLVM target. Do not set nixpkgs.config.rocmSupport (rebuilds the
  # world); pkgs.ollama-rocm is the prebuilt attr.
  services.ollama.package = pkgs.ollama-rocm;
  services.ollama.rocmOverrideGfx = "11.0.3";

  # ============================================================
  #  Never sleep — always-on desktop (phone-driven agents, Hermes).
  # ============================================================
  # Belt and braces on top of work-awake: even if PowerDevil or a stray
  # `systemctl suspend` asks, systemd refuses. Screen still blanks/locks.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # ============================================================
  #  Headless server mode (no screen, no keyboard)
  # ============================================================
  # This box lives in a cupboard and must come back by itself after a
  # reboot or power cut, with Grok Bot running, so agents can reach it.

  # --- 1. Disk unlocks itself using the TPM security chip -------------
  # The disks are encrypted. Normally boot stops and waits for the disk
  # password. The modern (systemd) boot stage can instead ask the
  # machine's built-in TPM chip for the key. If the TPM refuses (e.g.
  # Secure Boot settings changed), it falls back to asking for the
  # password as before, so plugging in a screen + keyboard always works.
  # One-time setup after rebuild: `sudo systemd-cryptenroll
  # --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/<uuid>` per disk.
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [ "tpm_crb" "tpm_tis" ];
  boot.initrd.luks.devices."luks-59050903-c8dd-4e51-ae6a-64f23eede32d".crypttabExtraOpts =
    [ "tpm2-device=auto" ];   # root disk
  boot.initrd.luks.devices."luks-5f8e2b15-11a6-4511-851c-2110170d173a".crypttabExtraOpts =
    [ "tpm2-device=auto" ];   # swap partition

  # --- 2. Log in automatically ---------------------------------------
  # Skip the login screen so the desktop session (and Grok Bot) starts
  # with nobody there. Safe-ish because the disk is still encrypted and
  # SSH only listens on the private Tailscale network.
  services.displayManager.autoLogin = { enable = true; user = "gpmare"; };

  # --- 3. Start Grok Bot on login ------------------------------------
  # Grok Bot only allows one copy of itself, so if Plasma also restores
  # it from the last session, the second launch just closes.
  home-manager.users.gpmare.xdg.configFile."autostart/grok-bot.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Grok Bot
    Exec=grok-bot
    Icon=grok-bot
    X-KDE-autostart-phase=2
  '';

  # --- 4. Lock down remote login (SSH) -------------------------------
  # Keys only, no passwords, no root. And only over Tailscale, not the
  # home Wi-Fi. The Dell's key is allowed in.
  services.openssh.openFirewall = false;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
  # Close everything on the normal network, including 3389 (remote
  # desktop, not wanted on this box). Only SSH was open besides that.
  networking.firewall.allowedTCPPorts = lib.mkForce [ ];
  users.users.gpmare.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMV3qDn/Id2r2S2sjLEJ1dWZR3d39duGmlpNx/7eLKno gpmare@dell"
  ];
}
