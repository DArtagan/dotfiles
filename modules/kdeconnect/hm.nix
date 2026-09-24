{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Pairing is all-or-nothing, and per-device config only binds devices already
  # paired at switch time. Deleting the plugins is the only form that holds for
  # every device, including one paired next week: the capability is not in the
  # package, so it is never advertised and no GUI toggle brings it back.
  #
  # An allowlist, because a blocklist missed `shareinputdevices` -- a second
  # plugin accepting `kdeconnect.mousepad.request`, which put "Remote input"
  # back in the phone's UI -- and would miss whatever a future release adds.
  allowedPlugins = [
    "battery"
    "clipboard"
    "ping"
  ];

  # Peers to reach over the tailnet. kdeconnect parses these with QHostAddress
  # and does no DNS, so MagicDNS names do not work here — IP literals only.
  tailnetPeers = [
    "100.64.0.5" # theguide-iphone17
  ];

  package = pkgs.kdePackages.kdeconnect-kde.overrideAttrs (prev: {
    postInstall = (prev.postInstall or "") + ''
      cd "$out/lib/qt-6/plugins/kdeconnect"
      keep=${lib.escapeShellArg (lib.concatMapStringsSep "|" (p: "kdeconnect_${p}.so") allowedPlugins)}
      for f in *.so; do
        if [[ ! "$f" =~ ^($keep)$ ]]; then
          rm -v "$f"
        fi
      done
      # Guard against a rename upstream silently emptying the allowlist.
      for p in ${lib.concatStringsSep " " allowedPlugins}; do
        test -e "kdeconnect_$p.so" || { echo "allowlisted plugin $p is missing"; exit 1; }
      done
    '';
  });
in
{
  services.kdeconnect = {
    inherit package;
    enable = true;
    indicator = false;
  };

  # Discovery is a LAN broadcast and does not cross the tailnet, so peers there
  # have to be named. This is kdeconnectd's own file — it writes `name` and
  # `keyAlgorithm` into it — so set the one key with KDE's own tool rather than
  # symlinking the whole thing read-only underneath the daemon.
  home.activation.kdeconnectCustomDevices = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} \
      --file ${config.xdg.configHome}/kdeconnect/config \
      --group General --key customDevices "${lib.concatStringsSep "," tailnetPeers}"
    # customDevices is read at startup and on network change, so a running
    # daemon would not see this until it restarts.
    run --quiet systemctl --user try-restart kdeconnect.service || true
  '';
}
