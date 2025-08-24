_: {
  # Remote nix build machines
  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "192.168.1.10";
      # copied from `/home/will/.ssh/id_ed25519`, should create a new one.
      sshKey = "/root/.ssh/id_ed25519";
      systems = [
        "x86_64-linux"
        "i686-linux"
      ];
      protocol = "ssh-ng";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
      mandatoryFeatures = [ ];
    }
  ];
}
