{ config, pkgs, ... }:
{
  # TODO: revert once https://github.com/NixOS/nixpkgs/issues/513245 is resolved
  nixpkgs.overlays = [
    (_: prev: {
      openldap = prev.openldap.overrideAttrs {
        doCheck = !prev.stdenv.hostPlatform.isi686;
      };
    })
  ];
  hardware.graphics.enable32Bit = true; # Needed for Epic Game Store

  environment.systemPackages = with pkgs; [
    lutris
    wineWow64Packages.stagingFull # Epic only works when run against the latest version of wine (circa 2026-01-04)
    pkgs.winetricks
    # bwrap uses --die-with-parent (prctl PR_SET_PDEATHSIG SIGKILL), so when
    # kickoff exits after launching steam, bwrap is immediately killed. From a
    # terminal fish stays open so bwrap survives. systemd-run --user reparents
    # the process to systemd, breaking the link to kickoff. Terminal PTY
    # launches (/dev/pts/*) run steam directly so output stays visible.
    (pkgs.writeShellScriptBin "steam" ''
      case "$(readlink /proc/$$/fd/1 2>/dev/null)" in
        /dev/pts/*) exec ${config.programs.steam.package}/bin/steam "$@" ;;
        *)          exec ${pkgs.systemd}/bin/systemd-run --user --collect -- ${config.programs.steam.package}/bin/steam "$@" ;;
      esac
    '')
  ];

  programs = {
    steam.enable = true;
  };
}
