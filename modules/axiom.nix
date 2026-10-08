# Axiom (francoisrob/axiom): PostgreSQL 18 for the canon engine and its portal.
#
# App code is cloned to ~/projects/axiom-portal and installed with its own
# tooling (mise + just); this module only provides the database.
# Shared by both hosts, but each machine has its own separate database —
# facts approved on one are not on the other (nothing syncs them).
{ config, lib, pkgs, username, ... }:
{
  services.postgresql = {
    enable = true;
    # Schema uses uuidv7() (PG18). stateVersion 26.05 would default lower, so pin it.
    package = pkgs.postgresql_18;
    # btree_gist / pgcrypto / pg_trgm are contrib and ship inside postgresql_18.
    # `axiom setup` connects as the OS user over the unix socket (peer) and needs superuser.
    ensureUsers = [ { name = username; ensureClauses.superuser = true; } ];
    # Service roles and the portal log in over localhost TCP with passwords.
    authentication = ''
      host  finplan_canon  all  127.0.0.1/32  scram-sha-256
      host  axiom_portal   all  127.0.0.1/32  scram-sha-256
      host  finplan_canon  all  ::1/128       scram-sha-256
      host  axiom_portal   all  ::1/128       scram-sha-256
    '';
  };
}
