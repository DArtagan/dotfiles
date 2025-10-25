# dotfiles & system configuration

## Nix
Nix configuration is using this approach as its spirit guide: https://github.com/Baitinq/nixos-config

### Update the system

One should first make sure all changes are committed to the repo.
```
nix flake update
sudo nixos-rebuild switch --flake .
```

## Generate NixOS iso

https://nixos.wiki/wiki/Creating_a_NixOS_live_CD

1. The configuration is already in `flake.nix`
2. `nix build .#nixosConfigurations.iso.config.system.build.isoImage`
3. The resulting image can be found in `result/iso/`

## thenixbeast partition set-up

Reference: https://wiki.nixos.org/wiki/ZFS

1. Create a NixOS liveUSB:
2. Boot the target machine using the liveUSB.
3. From a remote machine, SSH into the target machine, for running the following steps.
4. `sudo gdisk /dev/nvme0n1`
5. We'll need a boot partition (ESP), a swap partition, and a large partition for NixOS (the type will be "8300" "Linux filesystem").
6. Get the device IDs (ls /dev/disk/by-id/) and set them as variables like:
  ```
  BOOT=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part1
  SWAP=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part7
  DISK=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part8
  ```
7. Create the pool: `zpool create -o ashift=9 -o autotrim=on -O compression=zstd-9 -O mountpoint=none -O canmount=off -O xattr=sa -O acltype=posix -O dnodesize=auto -O atime=off normalization=formD -R /mnt rpool $DISK`
  * This SSD claims (`sudo fdisk -l`) 512 bytes as its ideal sector size, so going with `ashift=9`, even though `12` is the typical recommendation and often even `13` for SSDs.
  * `compression=zstd-9`: probably too much.  `on`/`lz4` is a no-brainer.  `zstd-3` is the default.  Cranking up the compression ratio this high might bottleneck on the CPU, rather than bottle-necking on reading off the NVME SSD.
  * `dnodesize=auto`
  * `atime=off`: disable writing the "access time" for every file read.
  * `normalization=formD`: something about using UTF-8 for filenames, and using the formD algorithm for comparison - which seems vaguely broadly compatible.
8. Create filesystems:
  ```
  zfs create -o canmount=noauto rpool/root
  zfs create rpool/home
  zfs create rpool/nix
  zfs create rpool/var
  ```
9. Mount those filesystems:
  ```
  mount -o X-mount.mkdir -o zfsutil -t zfs rpool/root /mnt
  mount -o X-mount.mkdir -o zfsutil -t zfs rpool/home /mnt/home
  mount -o X-mount.mkdir -o zfsutil -t zfs rpool/nix /mnt/nix
  mount -o X-mount.mkdir -o zfsutil -t zfs rpool/var /mnt/var
  ```
10. Set a password: `passwd`
11. Note the target machine's ip address for the next step: `ip addr`
12. Deploy.  In a separate terminal, on the remote machine run:
  ```
  nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/thenixbeast/facter.json --phases kexec,install,reboot --flake .#thenixbeast --target-host root@<ip address>
  ```


## Deprecated dotfiles:
* chunkwm: project is no longer developed.  Move to `yabai` instead.
* fish: configuration moved to `home.nix`, now ceasing to maintain the `fish` directory.
* termite: terminal deprecated.  Author recommends using `alacritty` instead.
* uzbl: author last updated it in 2016.  Move to `qutebrowser` instead.
* zsh: ceasing to maintain the configuration files.  `fish` has all the shell niceness, batteries included.
