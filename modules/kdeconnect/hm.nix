# Home-manager half of the kdeconnect module: the per-session daemon.
#
# Pairs with ./default.nix (package + firewall). Clipboard sync works here
# because the plugin goes through KSystemClipboard, which needs
# ext_data_control_manager_v1 / zwlr_data_control_manager_v1 — protocols
# sway/wlroots implements (and GNOME's Wayland session does not, which is why
# clipboard sync is reported broken there and not here).
_: {
  services.kdeconnect = {
    enable = true;
    # The indicator pulls in tray.target, which nothing in this config defines
    # (see the commented-out block under steamdeck in flake.nix). kdeconnect-app
    # and kdeconnect-cli cover pairing without it.
    indicator = false;
  };
}
