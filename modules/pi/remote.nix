{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
# Browser access to pi sessions over the tailnet, with two UIs on trial side by side.
# Neither starts on its own; see README.md, "Remote access".
let
  agegr-pi-web = pkgs.callPackage ../../pkgs/agegr-pi-web/package.nix { };
  pi-remote-control = pkgs.callPackage ../../pkgs/pi-remote-control/package.nix { };
  host = osConfig.networking.hostName;
  fqdn = "${host}.forge.local";
in
{
  # Both listen on every address, IPv4 and IPv6, and rely on the host firewall to keep
  # them off the LAN: it trusts only loopback, tailscale0, and the Steam Deck's hotspot.
  # Neither asks for a password; each rejects requests from other origins.
  systemd.user.services = {
    pi-web = {
      Unit.Description = "pi-web (agegr): browser UI for pi sessions";
      Service = {
        ExecStart = "${lib.getExe agegr-pi-web} --hostname :: --port 30141 --no-open";
        WorkingDirectory = "%h";
        Environment = [
          # Host names it serves besides localhost and IP addresses, which with its Origin
          # checks is what stops DNS rebinding and cross-site requests.
          "PI_WEB_ALLOWED_HOSTS=${fqdn},${host}"
          "PI_WEB_SKIP_VERSION_CHECK=1"
          # Sessions run pi's bash tool with this PATH; a user service gets almost none.
          "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        ];
      };
    };

    pi-remote-control = {
      Unit.Description = "Pi Remote Control (prc): browser UI for pi TUI sessions attached with /rc";
      Service = {
        # Writes ~/.config/prc/config.json (agent token, admin password) on first start.
        ExecStartPre = toString (
          pkgs.writeShellScript "prc-setup" ''
            [ -e "''${XDG_CONFIG_HOME:-$HOME/.config}/prc/config.json" ] ||
              ${lib.getExe pi-remote-control} setup >/dev/null
          ''
        );
        ExecStart = "${lib.getExe pi-remote-control} serve";
        Environment = [
          "RC_HOST=::"
          # The only origin the browser UI accepts. The extension keeps connecting over
          # loopback, through the publicOrigin that `prc setup` puts in config.json.
          "RC_PUBLIC_ORIGIN=http://${fqdn}:8787"
        ];
      };
    };
  };

  # Load the /rc extension. piSettings rewrites `packages` wholesale on every switch, so
  # this adds to it afterwards rather than going through mergeJsonInto.
  home.activation.piRemoteControlExtension = lib.hm.dag.entryAfter [ "piSettings" ] ''
    settingsFile="$HOME/.pi/agent/settings.json"
    merged=$(${lib.getExe pkgs.jq} --arg ext "${pi-remote-control.extension}" \
      '.packages = ((.packages // []) | map(select(contains("pi-remote-control-extension") | not))) + [$ext]' \
      "$settingsFile")
    echo "$merged" > "$settingsFile"
  '';
}
