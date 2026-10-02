{ config, lib, ... }:
let
  cfg = config.my.distributedBuilders;
  inherit (config.networking) hostName;

  # Every host sets max-jobs * cores to twice its threads. A remote build runs with the
  # sending host's `cores`, so maxJobs gives senders the same budget: twice the builder's
  # threads, divided by the senders' `cores` (8 on steamdeck, the only sender).
  # speedFactor only ranks builders against each other (CPU GHz * threads, normalized to
  # mini-nas, matching the mini-nas repo).
  machines = {
    thenixbeast = {
      maxJobs = 6;
      speedFactor = 4;
    };
    mini-nas = {
      maxJobs = 2;
      speedFactor = 1;
    };
  };
in
{
  options.my.distributedBuilders = {
    builders = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (lib.attrNames machines));
      default = [ ];
      example = [ "thenixbeast" ];
      description = ''
        Hosts to send builds to. Nix takes any free slot on a builder before building
        locally, whatever its speedFactor, so only list hosts faster than this one.
      '';
    };

    acceptBuilds = lib.mkEnableOption "builds sent from the other hosts, as the `nix` user over SSH";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.builders != [ ]) {
      sops.secrets."distributed_builders/ssh_private_key".sopsFile = ./secrets.yaml;

      nix = {
        distributedBuilds = true;
        buildMachines = map (name: {
          inherit (machines.${name}) maxJobs speedFactor;
          protocol = "ssh-ng";
          hostName = "${name}.forge.local";
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
        }) cfg.builders;
        settings = {
          # Read the machine list from a file only this host has. A builder adopts the
          # `builders` value of a trusted client, so a build sent from here reads
          # /etc/nix/machines.${hostName} on the builder, finds nothing, and runs there
          # rather than being forwarded again. Forwarding is what let builds loop back
          # to the host that sent them, and deadlock on its locks (NixOS/nix#2029).
          builders = "@/etc/nix/machines.${hostName}";
          builders-use-substitutes = true;
        };
      };

      environment.etc."nix/machines.${hostName}".source = config.environment.etc."nix/machines".source;

      # Without this, a builder that's switched off stalls every build for the full TCP
      # connect timeout before Nix moves on.
      programs.ssh.extraConfig = ''
        Match user nix host ${lib.concatMapStringsSep "," (name: "${name}.forge.local") cfg.builders}
          ConnectTimeout 5
        Match all
      '';
    })

    (lib.mkIf cfg.acceptBuilds {
      nix.settings.trusted-users = [ "nix" ];

      users = {
        users.nix = {
          isSystemUser = true;
          group = "nix";
          # The key can only talk to the Nix daemon, which is all `ssh-ng` builds need.
          # It stays a trusted user: builders must accept unsigned build inputs, and
          # adopt the sender's `builders` setting (see above).
          openssh.authorizedKeys.keys = [
            "restrict,command=\"${config.nix.package}/bin/nix-daemon --stdio\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEufEieU/OuOiSA3jfmUo4ro9UQFC2tMkzL/NdRuP3Qh"
          ];
          useDefaultShell = true;
        };

        groups.nix = { };
      };

      services.openssh.enable = true;
    })

    {
      programs.ssh.knownHosts = {
        mini-nas = {
          extraHostNames = [
            "192.168.1.11"
            "mini-nas.forge.local"
          ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFxk3SUTMe8de1v8ultvy4cR7N5/Rs4Q8ozX4nl6kOwA";
        };
        steamdeck = {
          extraHostNames = [
            "192.168.1.12"
            "steamdeck.forge.local"
          ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC3g7cDUbFypZlqSxWfblUe8E+I7lGxkJTmAw5VaWK89";
        };
        thenixbeast = {
          extraHostNames = [
            "192.168.1.10"
            "thenixbeast.forge.local"
          ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEB74qOTioDeqED1VPlfAHWsQuh5x5TQs7kji2S8QiEM";
        };
      };
    }
  ];
}
