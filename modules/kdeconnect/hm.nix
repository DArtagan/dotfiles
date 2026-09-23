# Home-manager half of the kdeconnect module: the per-session daemon and the
# per-device settings that decide what a paired phone may do here.
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

  pluginLines =
    device: lib.concatMapStrings (p: "kdeconnect_${p}Enabled=false\n") device.disabledPlugins;

  deviceFiles = lib.concatMapAttrs (id: device: {
    # kdeconnectd writes plugin state here when toggled in kdeconnect-settings;
    # as a read-only symlink those toggles no longer stick, which is the point.
    "kdeconnect/${id}/config" = lib.mkIf (device.disabledPlugins != [ ]) {
      text = ''
        [Plugins]
        ${pluginLines device}'';
    };

    "kdeconnect/${id}/kdeconnect_clipboard/config" = lib.mkIf (!device.clipboardAutoShare) {
      text = ''
        [General]
        autoShare=false
      '';
    };
  }) cfg.devices;
in
{
  options.kdeconnect.devices = lib.mkOption {
    default = { };
    description = ''
      Per-device settings, keyed by the paired device ID that
      `kdeconnect-cli -l` prints. Re-pairing a device regenerates its ID, so
      these keys have to be updated then.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          disabledPlugins = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "mousepad" ];
            description = ''
              Plugins this device may not use, named without the
              `kdeconnect_` prefix. Pairing is all-or-nothing, so this is the
              only place to say that a paired phone may sync the clipboard but
              not, say, type into the machine (`mousepad`).
            '';
          };

          clipboardAutoShare = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether to push this desktop's clipboard on every connection.
              Leaving it on breaks phone → desktop pushes outright: the
              desktop overwrites the phone's clipboard as the link
              re-establishes, so the phone sends our own text back.
            '';
          };
        };
      }
    );
  };

  config = {
    services.kdeconnect = {
      enable = true;
      indicator = false;
    };

    xdg.configFile = deviceFiles;
  };
}
