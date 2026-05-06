{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ docker-compose ];
  hardware.nvidia-container-toolkit.enable = true;

  # When nh os switch deploys a new nvidia driver, the old kernel module stays
  # loaded (display server holds it). The CDI generator would fail with
  # "Driver/library version mismatch". ExecCondition detects this and exits 1,
  # which systemd treats as "activated successfully, but skipped" — no failure
  # cascade to podman. The udev rule re-runs the generator after reboot when
  # the new kernel module loads.
  systemd.services.nvidia-container-toolkit-cdi-generator = {
    serviceConfig.ExecCondition = toString (
      pkgs.writeShellScript "nvidia-version-check" ''
        expected="${config.hardware.nvidia.package.version}"
        actual=$(grep -oP 'Kernel Module\s+\K[0-9.]+' /proc/driver/nvidia/version 2>/dev/null || echo "")
        if [ -z "$actual" ] || [ "$actual" != "$expected" ]; then
          echo "nvidia kernel ($actual) != expected ($expected); deferring CDI generation until reboot" >&2
          exit 1
        fi
      ''
    );
  };

  virtualisation = {
    containers = {
      enable = true;
      containersConf = {
        settings = {
          engine = {
            compose_warning_logs = false;
          };
        };
      };
      storage.settings = {

      };
    };
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
