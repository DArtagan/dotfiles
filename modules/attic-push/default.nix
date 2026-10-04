# Pushes everything this host builds to the `public` cache on mini-nas, without making
# builds wait on the upload. Mirrors modules/attic in the mini-nas repo.
#
# The hosts share one token, in ./secrets.yaml: Attic can't revoke a single token anyway,
# only rotate the key that signs them all. See "Adding a host" in README.md.
{ config, pkgs, ... }:
let
  queued-build-hook = pkgs.callPackage ../../pkgs/queued-build-hook/package.nix { };

  sockPath = "/run/post-build-hook.sock";

  # Points attic at the token systemd hands the daemon, so no `attic login` is needed.
  atticConfig = pkgs.writeTextDir "attic/config.toml" ''
    [servers.mini-nas]
    endpoint = "http://mini-nas.forge.local:8770"
    token-file = "/run/credentials/queued-build-hook.service/attic-push-token"
  '';

  # Run by the queued-build-hook daemon, which retries it on failure.
  pushHook = pkgs.writeShellScript "attic-push" ''
    exec ${pkgs.attic-client}/bin/attic push mini-nas:public $OUT_PATHS
  '';

  # Nix runs the post-build-hook synchronously, while still holding the build's output
  # locks, so it only hands the paths to the daemon.
  enqueueHook = pkgs.writeShellScript "enqueue-post-build-hook" ''
    exec ${queued-build-hook}/bin/queued-build-hook queue --socket ${sockPath}
  '';
in
{
  sops.secrets."attic/push_token".sopsFile =
    if builtins.pathExists ./secrets.yaml then
      ./secrets.yaml
    else
      throw "modules/attic-push/secrets.yaml is missing. Mint the push token: see \"Pushing a host's builds to `public`\" in README.md.";

  # A queue rather than `attic watch-store`: watch-store never retries a failed upload
  # and skips every `-source` path.
  systemd.sockets.queued-build-hook = {
    description = "Post-build-hook socket";
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = sockPath;
      SocketUser = "root";
      SocketMode = "0600";
    };
  };

  systemd.services.queued-build-hook = {
    description = "Push built store paths to Attic on mini-nas";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "queued-build-hook.socket"
    ];
    requires = [ "queued-build-hook.socket" ];
    environment.XDG_CONFIG_HOME = "${atticConfig}";
    serviceConfig = {
      # Retries ride out an hour of mini-nas being unreachable. Pushes still queued after
      # that, or when this service stops, are dropped; the queue only lives in memory.
      # Concurrency is capped because each finished derivation queues its own push, and
      # a large build otherwise starts hundreds at once against atticd's SQLite.
      ExecStart = "${queued-build-hook}/bin/queued-build-hook daemon --hook ${pushHook} --retry-interval 60 --retries 60 --concurrency 2";
      DynamicUser = true;
      LoadCredential = "attic-push-token:${config.sops.secrets."attic/push_token".path}";
      Restart = "on-failure";
    };
  };

  nix.settings.post-build-hook = enqueueHook;
}
