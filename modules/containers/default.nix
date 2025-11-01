{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ docker-compose ];
  hardware.nvidia-container-toolkit.enable = true;
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
