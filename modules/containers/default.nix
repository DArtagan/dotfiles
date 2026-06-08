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
    # loaded (display server holds it), so the new userspace mismatches it. Two
    # things keep the switch (and the GPU containers) healthy until the reboot
    # that loads the new module:
    #
    #   1. ExecCondition: on a driver bump the generator's ExecStart changes, so
    #      switch restarts it; it would then call nvidia-ctk -> NVML and fail on
    #      the version mismatch, breaking the switch. The guard exits 1 instead,
    #      which systemd treats as "activated successfully, but skipped".
    #   2. RuntimeDirectoryPreserve: the generator writes its spec to
    #      /run/cdi (a RuntimeDirectory, which systemd deletes on stop by
    #      default). Preserving it means the *old* spec — still pointing at the
    #      old, still-present nvidia store paths that match the loaded module —
    #      survives the switch. The GPU containers can restart and resolve
    #      nvidia.com/gpu=all against it with no downtime. The udev rule
    #      regenerates the spec for the new driver once it loads on reboot.
    systemd.services.nvidia-container-toolkit-cdi-generator = {
      serviceConfig = {
        ExecCondition = toString config.nvidiaContainers.versionGuard;
        RuntimeDirectoryPreserve = "yes";
      };
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
