# Learning-platform autograder (nucbox only).
#
# Rootless podman + a Nix-built, reproducible grader image
# (python3, pytest, gcc, make). Docker stays the oci-containers backend
# (dockerCompat = false), so Hermes keeps working.
#
# Usage:  learn-grade <submission-dir>
#   Inside the container the submission is copied to /build (scratch).
#   If it contains grade.sh, that is run; else if it has a Makefile,
#   `make test`; else `pytest -q`. Exit code is the grader's exit code
#   (124 = 30 s timeout). Output is capped at 64 KiB.
#
# Sandbox: --network=none, read-only root, /tmp tmpfs 64m noexec,
# /build tmpfs 64m (exec needed to run compiled C), 1 CPU, 512 MB RAM,
# no swap, 128 pids, all caps dropped, no-new-privileges, uid 65534.

{ pkgs, username, ... }:

let
  graderImage = pkgs.dockerTools.buildLayeredImage {
    name = "learn-grader";
    tag = "1";
    contents = with pkgs; [
      bashInteractive coreutils gnugrep gnused findutils gnumake gcc
      (python3.withPackages (p: [ p.pytest ]))
    ];
    config = {
      Env = [ "PATH=/bin" "HOME=/tmp" "PYTHONDONTWRITEBYTECODE=1" ];
      WorkingDir = "/build";
    };
  };

  learn-grade = pkgs.writeShellScriptBin "learn-grade" ''
    set -euo pipefail
    sub="''${1:?usage: learn-grade <submission-dir>}"
    sub="$(${pkgs.coreutils}/bin/realpath "$sub")"
    [ -d "$sub" ] || { echo "not a directory: $sub" >&2; exit 2; }
    podman=${pkgs.podman}/bin/podman
    img=localhost/learn-grader:1
    if ! $podman image exists "$img"; then
      $podman load -q -i ${graderImage} >/dev/null
    fi
    set +e
    ${pkgs.coreutils}/bin/timeout --kill-after=5 30 \
      $podman run --rm -i \
        --network=none --read-only \
        --tmpfs /tmp:size=64m,noexec \
        --tmpfs /build:size=64m,exec,mode=1777 \
        --cpus=1 --memory=512m --memory-swap=512m --pids-limit=128 \
        --cap-drop=ALL --security-opt=no-new-privileges \
        --user 65534:65534 \
        -v "$sub":/submission:ro \
        "$img" bash -c '
          cp -r /submission/. /build/ && cd /build
          if [ -f grade.sh ]; then bash grade.sh
          elif [ -f Makefile ]; then make -s test
          else python3 -m pytest -q -p no:cacheprovider
          fi' 2>&1 | ${pkgs.coreutils}/bin/head -c 65536
    rc=''${PIPESTATUS[0]}
    exit $rc
  '';
in
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
  };

  # Rootless podman needs subuid/subgid ranges for the user.
  users.users.${username}.autoSubUidGidRange = true;

  environment.systemPackages = [ learn-grade ];
}
