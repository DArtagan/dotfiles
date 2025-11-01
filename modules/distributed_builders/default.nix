{ config, ... }:
{
  sops.secrets = {
    "distributed_builders/ssh_private_key" = {
      sopsFile = ./secrets.yaml;
    };
    "distributed_builders/ssh_public_key" = {
      sopsFile = ./secrets.yaml;
    };
  };

  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "192.168.1.10";
        sshKey = config.sops.secrets."distributed_builders/ssh_private_key".path;
        sshUser = "nix";
        systems = [
          "x86_64-linux"
          "i686-linux"
        ];
        protocol = "ssh-ng";
        maxJobs = 12;
        speedFactor = 2;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
      }
    ];
    settings.trusted-users = [ "nix" ];
  };

  users.users.nix = {
    isSystemUser = true;
    home = "/var/empty";
    group = "nix";
    openssh.authorizedKeys.keyFiles = [
      config.sops.secrets."distributed_builders/ssh_public_key".path
    ];
  };

  users.groups.nix = { };
}
