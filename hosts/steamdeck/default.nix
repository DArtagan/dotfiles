{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  sops =
    let
      host_ssh_private_key = "/etc/ssh/ssh_host_ed25519_key";
      user_ssh_private_key = "/home/willy/.ssh/id_ed25519";
    in
    {
      defaultSopsFile = ./secrets.yaml;
      age.sshKeyPaths = [ host_ssh_private_key ];
      environment.SOPS_AGE_SSH_PRIVATE_KEY_FILE = host_ssh_private_key;
      secrets = {
        "users/willy/hashedPassword".neededForUsers = true;
        "users/willy/ssh_private_key" = {
          owner = "willy";
          mode = "600";
          path = user_ssh_private_key;
        };
        "users/willy/ssh_public_key" = {
          owner = "willy";
          mode = "644";
          path = user_ssh_private_key + ".pub";
        };
        "users/willy/wireguard_private_key" = { };
        "wifi/hotspot_psk" = { };
      };
    };

  # Lives here rather than with the other `my.*` settings in flake.nix because
  # pskFile has to reference this host's sops secret.
  my.hotspot = {
    enable = true;
    ssid = "steam_powered_internet";
    pskFile = config.sops.secrets."wifi/hotspot_psk".path;
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 15;
    };
    efi.canTouchEfiVariables = true;
  };

  # Without this the card sits in regulatory domain 00 (the world domain), which
  # marks all of 5 GHz passive-scan: the radio waits to overhear a beacon rather
  # than probing for the network, and transmit power is capped. Seen as
  # NetworkManager reporting "the Wi-Fi network could not be found" for an AP
  # its own scan list contained, and repeated "association took too long".
  # hostapd sets the domain from its country_code while the hotspot runs and it
  # reverts to 00 when hostapd stops, so the radio is otherwise only correct
  # while the hotspot happens to be up.
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="US"
  '';

  networking = {
    hostName = "steamdeck";

    wg-quick.interfaces = {
      # Launch using: `sudo systemctl restart wg-quick-wg0.service`
      wg0 = {
        # TODO: make the rest of this wireguard config a reusable module across hosts, with this address and privateKey the only things passed in.
        address = [ "10.0.1.11/32" ];
        autostart = false;
        dns = [
          "192.168.0.202"
          "1.1.1.1"
        ];
        privateKeyFile = config.sops.secrets."users/willy/wireguard_private_key".path;
        peers = [
          {
            publicKey = "ky2MMTdJmLKAT/QwgUNpRCmXJb1Mn4Qs/51rqFq6/jo=";
            allowedIPs = [
              "10.0.1.0/24"
              "192.168.0.0/24"
            ];
            endpoint = "immortalkeep.com:51820";
          }
        ];
        postUp = [
          "${pkgs.inetutils}/bin/ping -c1 10.0.1.1"
        ];
      };
    };
  };

  # Hibernate rather than lose the session to a flat battery. Left in suspend,
  # the Deck drains ~0.7-1%/h, so a suspend begun low dies overnight; awake,
  # Jovian leaves the critical-battery action to vpower and Steam, which power
  # off at ~0.5%.
  #
  # The image goes to this swapfile (zram is RAM, so can't hold it), sized to
  # RAM. Its lower auto priority keeps zram in use first for ordinary swapping.
  # No resume=/resume_offset: systemd-hibernate records the swapfile's location
  # in the HibernateLocation EFI variable, which the initrd resumes from.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  systemd = {
    # Every suspend (GNOME, Steam, lid, power button) goes through
    # systemd-suspend.service, so make it suspend-then-hibernate. It hibernates
    # after 2h, or at once if the battery is already below 5%.
    services.systemd-suspend.serviceConfig.ExecStart = [
      ""
      "${config.systemd.package}/lib/systemd/systemd-sleep suspend-then-hibernate"
    ];
    # The battery has no ACPI _BTP alarm (BAT1/alarm reads 0), so systemd would
    # also wake on the RTC every SuspendEstimationSec (default 1h) to measure the
    # drain. At ~1%/h that only matters below ~7%, so match it to the delay: one
    # wake, then hibernate.
    sleep.settings.Sleep = {
      HibernateDelaySec = "2h";
      SuspendEstimationSec = "2h";
    };

    # With Bluetooth on, the Deck wakes within seconds of every suspend; with it
    # soft-blocked it stays asleep. Its wake line is a GPIO the firmware arms
    # (pin 54), which no power/wakeup knob reaches. Bazzite traced the same
    # symptom on the OLED to Bluetooth firmware: the chip loads the stock
    # qca/hpbtfw21.tlv here, and Valve's firmware has no replacement for it
    # (https://github.com/ublue-os/bazzite/issues/3124). So block Bluetooth for
    # as long as sleep.target is up, and unblock it after only if this blocked it.
    #
    # Coming back from hibernation, the chip has lost power and its firmware,
    # but hci_uart_qca doesn't set it up again: every HCI_Reset times out (-110)
    # and Bluetooth can't be turned on. Rebinding the driver reruns its setup,
    # but only on a chip hibernation has reset. Rebinding one that's running, or
    # mid power-on, wedges it until it loses power (0xfc00 tx timeouts). So the
    # sleep hook below flags a resume from hibernation, and the rebind happens
    # while Bluetooth is still blocked. It makes a new rfkill device, which
    # systemd-rfkill gives the saved state, so let that land before unblocking.
    services.bluetooth-sleep-block = {
      description = "Block Bluetooth while asleep";
      wantedBy = [ "sleep.target" ];
      before = [ "sleep.target" ];
      unitConfig.StopWhenUnneeded = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.util-linux ];
      script = ''
        if rfkill -n -o SOFT list bluetooth | grep -q '^unblocked'; then
          rfkill block bluetooth
          touch /run/bluetooth-sleep-blocked
        fi
      '';
      preStop = ''
        if [ -e /run/bluetooth-rebind ]; then
          rm /run/bluetooth-rebind
          # Never let a failed rebind skip the unblock below.
          echo serial0-0 > /sys/bus/serial/drivers/hci_uart_qca/unbind || true
          echo serial0-0 > /sys/bus/serial/drivers/hci_uart_qca/bind || true
          udevadm settle
          sleep 1
        fi
        if [ -e /run/bluetooth-sleep-blocked ]; then
          rfkill unblock bluetooth
          rm /run/bluetooth-sleep-blocked
        fi
      '';
    };
  };

  # systemd runs sleep hooks with next to no PATH, so name binaries in full.
  environment.etc."systemd/system-sleep/bluetooth-rebind".source =
    pkgs.writeShellScript "bluetooth-rebind" ''
      if [ "$1" = post ] && [ "''${SYSTEMD_SLEEP_ACTION:-$2}" = hibernate ]; then
        ${pkgs.coreutils}/bin/touch /run/bluetooth-rebind
      fi
    '';

  services = {
    # Awake, hibernate at upower's PercentageAction (2%), ahead of vpower/Steam.
    upower.criticalPowerAction = lib.mkForce "Hibernate";

    # Only the power button wakes the Deck, plus the RTC, which suspend-then-
    # hibernate needs to wake it for hibernation. Everything else that can (the
    # USB controllers, PCIe ports and Wi-Fi, the lid sensor and battery) is
    # turned off. Not covered: wake paths with no power/wakeup knob, such as EC
    # events and the Bluetooth chip's GPIO (see bluetooth-sleep-block above).
    udev.extraRules = ''
      ACTION!="remove", SUBSYSTEM!="power_supply", ATTR{power/wakeup}=="enabled", KERNEL!="LNXPWRBN:00|PNP0C0C:00|PNP0B00:00|alarmtimer.*", ATTR{power/wakeup}="disabled"
    '';

    # Enable the GNOME Desktop Environment.
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    xserver.enable = true;
  };

  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator # app icon system tray
  ];

  # TODO: unify usernames to `will` and move this all to configuration.nix
  users.users = {
    willy = {
      # TODO: impermanence, https://github.com/Mic92/sops-nix?tab=readme-ov-file#setting-a-users-password
      hashedPasswordFile = config.sops.secrets."users/willy/hashedPassword".path;
      home = "/home/willy";
      description = "Willy";
      isNormalUser = true;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
    };
  };

  programs = {
    _1password-gui = {
      # TODO: set here to match the one user declared here
      polkitPolicyOwners = [ "willy" ];
    };
  };

  nix = {
    # Builds only get the CPU when nothing else, such as a game, wants it.
    daemonCPUSchedPolicy = "idle";
    settings = {
      # Enable users to be trusted users of the Nix store (useful for devenv)
      # TODO: set here to match the one user declared here
      trusted-users = [ "willy" ];
      # Builds sent to thenixbeast and mini-nas run with these `cores` too, so a big
      # one, like the kernel, gets 8 threads there (see modules/distributed_builders).
      cores = 8;
      max-jobs = 2;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database
  # versions on your system were taken. It‘s perfectly fine and
  # recommended to leave this value at the release version of the first
  # install of this system. Before changing this value read the
  # documentation for this option (e.g. man configuration.nix or on
  # https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
