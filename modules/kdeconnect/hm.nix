# KDE Connect: clipboard sync with the phone, on sway sessions.
#
# Clipboard sync works on sway because the plugin goes through
# KSystemClipboard, which needs ext_data_control_manager_v1 /
# zwlr_data_control_manager_v1 — protocols sway/wlroots implements (and GNOME's
# Wayland session does not, which is why clipboard sync is reported broken
# there and not here). See ./README.md.
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
  forbiddenPlugins = [
    "findmyphone"
    "findthisdevice"
    "mousepad" # a keyboard and mouse for this machine
    "presenter"
    "runcommand" # remote execution
    "share" # drops files here, opens URLs here; files go over Taildrop
    "shareinputdevicesremote"
  ];

  # Peers to reach over the tailnet. kdeconnect parses these with QHostAddress
  # and does no DNS, so MagicDNS names do not work here — IP literals only.
  tailnetPeers = [
    "100.64.0.5" # theguide-iphone17
  ];

  package = pkgs.kdePackages.kdeconnect-kde.overrideAttrs (prev: {
    # Auto-sharing the clipboard on every connection breaks phone -> desktop
    # pushes outright: the desktop overwrites the phone's clipboard as the link
    # re-establishes, so the phone sends our own text back. The default lives
    # in the source, and flipping it here beats a config file per paired device.
    postPatch = (prev.postPatch or "") + ''
      substituteInPlace plugins/clipboard/clipboardplugin.cpp \
        --replace-fail 'QStringLiteral("sendUnknown"), true' \
                       'QStringLiteral("sendUnknown"), false'
    '';

    postInstall = (prev.postInstall or "") + ''
      for p in ${lib.concatStringsSep " " forbiddenPlugins}; do
        rm -v "$out/lib/qt-6/plugins/kdeconnect/kdeconnect_$p.so"
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
