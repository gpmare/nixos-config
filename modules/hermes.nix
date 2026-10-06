# Hermes Agent (Nous Research): always-on gateway + local dashboard
# in the official Docker image.
#
# State lives on the host at ~/.hermes (bind-mounted to /opt/data).
# Dashboard username/password live in ~/.hermes/dashboard.env — not here.
# After the first switch, complete setup once:
#   docker exec -it hermes hermes setup
# Dashboard: http://127.0.0.1:9119  (bound to localhost only)

{ config, username, ... }:

let
  dataDir = "/home/${username}/.hermes";
  # Dynamic UIDs are null at eval time; this host's gpmare is 1000:100.
  uid =
    if config.users.users.${username}.uid == null
    then "1000"
    else toString config.users.users.${username}.uid;
  gid = toString config.users.groups.${config.users.users.${username}.group}.gid;
in
{
  virtualisation.docker.enable = true;

  # stateVersion >= 22.05 defaults this to podman; pin docker to match
  # the official Hermes image docs.
  virtualisation.oci-containers = {
    backend = "docker";
    containers.hermes = {
      image = "nousresearch/hermes-agent:latest";
      autoStart = true;
      cmd = [ "gateway" "run" ];
      ports = [
        "127.0.0.1:8642:8642"  # OpenAI-compatible API (off until enabled in .env)
        "127.0.0.1:9119:9119"  # web dashboard
      ];
      volumes = [
        "${dataDir}:/opt/data"
      ];
      environment = {
        HERMES_DASHBOARD = "1";
        HERMES_UID = uid;
        HERMES_GID = gid;
      };
      environmentFiles = [
        "${dataDir}/dashboard.env"
      ];
      extraOptions = [
        "--shm-size=1g"
        "--memory=4g"
        "--cpus=2"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0700 ${username} users -"
  ];
}
