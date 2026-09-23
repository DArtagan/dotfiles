# Home-manager half of the kdeconnect module: the per-session daemon, plus the
# clipboard plugin settings that decide whether phone -> desktop works at all.
#
# Clipboard sync works on sway because the plugin goes through
# KSystemClipboard, which needs ext_data_control_manager_v1 /
# zwlr_data_control_manager_v1 — protocols sway/wlroots implements (and GNOME's
# Wayland session does not, which is why clipboard sync is reported broken
# there and not here). See ./README.md.
{
  config,
  lib,
  ...
}:
let
  cfg = config.kdeconnect;
in
{
  options.kdeconnect.clipboardAutoShareDisabled = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "0b01f8bf_a921_4464_be14_346b51cf92ad" ];
    description = ''
      Paired device IDs whose clipboard plugin must not auto-share this
      desktop's clipboard on every connection. Leaving auto-share on breaks
      phone -> desktop pushes outright: the desktop overwrites the phone's
      clipboard as the link re-establishes, so the phone sends our own text
      back. `kdeconnect-cli -l` prints the current IDs; re-pairing a device
      regenerates its ID, so this list has to be updated then.
    '';
  };

  config = {
    services.kdeconnect = {
      enable = true;
      indicator = false;
    };

    # kdeconnectd owns this directory, so these land as read-only symlinks:
    # toggling auto-share in kdeconnect-settings will not stick while a device
    # is listed here. That is the point -- the setting is load-bearing.
    xdg.configFile = builtins.listToAttrs (
      map (id: {
        name = "kdeconnect/${id}/kdeconnect_clipboard/config";
        value.text = ''
          [General]
          autoShare=false
        '';
      }) cfg.clipboardAutoShareDisabled
    );
  };
}
