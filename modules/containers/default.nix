{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Shared ExecCondition guard: succeeds only when the loaded nvidia kernel
  # module matches the deployed userspace driver. Used by the CDI generator and
  # by any GPU container service so they all defer together across a driver
  # update (see usage in modules/ai-server).
  options.nvidiaContainers.versionGuard = lib.mkOption {
    type = lib.types.path;
    readOnly = true;
    description = "Path to a script usable as a systemd ExecCondition that exits non-zero (skip) when the running nvidia kernel module version does not match the deployed driver.";
    default = pkgs.writeShellScript "nvidia-version-check" ''
      expected="${config.hardware.nvidia.package.version}"
      actual=$(grep '^NVRM' /proc/driver/nvidia/version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "")
      if [ -z "$actual" ] || [ "$actual" != "$expected" ]; then
        echo "nvidia kernel ($actual) != expected ($expected); deferring until reboot" >&2
        exit 1
      fi
    '';
  };

  config = {
    environment.systemPackages = with pkgs; [ docker-compose ];
    hardware.nvidia-container-toolkit.enable = true;

    # When nh os switch deploys a new nvidia driver, the old kernel module stays
    # loaded (display server holds it). The CDI generator would fail with
    # "Driver/library version mismatch". ExecCondition detects this and exits 1,
    # which systemd treats as "activated successfully, but skipped" — no failure
    # cascade to podman. The udev rule re-runs the generator after reboot when
    # the new kernel module loads.
    systemd.services.nvidia-container-toolkit-cdi-generator = {
      serviceConfig.ExecCondition = toString config.nvidiaContainers.versionGuard;
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
  };
}
