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
    buildMachines =
      let
        protocol = "ssh-ng";
        sshKey = config.sops.secrets."distributed_builders/ssh_private_key".path;
        sshUser = "nix";
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        systems = [
          "x86_64-linux"
          "i686-linux"
        ];
      in
      [
        # speedFactor calculation: CPU GHz * CPU threads
        #   thenixbeast: 5.5 * 24 = 132
        #   steamdeck: 3.5 * 8 = 28
        {
          inherit
            protocol
            sshKey
            sshUser
            supportedFeatures
            systems
            ;
          hostName = "192.168.1.10"; # thenixbeast
          maxJobs = 12;
          speedFactor = 132;
        }
        {
          inherit
            protocol
            sshKey
            sshUser
            supportedFeatures
            systems
            ;
          hostName = "192.168.1.12"; # steamdeck
          maxJobs = 4;
          speedFactor = 28;
        }
      ];
    settings = {
      builders-use-substitutes = true;
      trusted-users = [ "nix" ];
    };
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
