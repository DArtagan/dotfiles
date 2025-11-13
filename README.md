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
4. Write to the USB drive (assuming `/dev/sdb` in this example - double check!): `sudo dd if=results/iso/<distro_name>.iso of=/dev/<sdb> status=progress`

## thenixbeast partition set-up

Reference: https://wiki.nixos.org/wiki/ZFS

1. Create a NixOS liveUSB (instructions above)
2. Generate a host SSH key:
  ```
  TEMP_SSH=$(mktemp -d)
  install -d -m755 "$TEMP_SSH/etc/ssh"
  ssh-keygen -t ed25519 -N "" -f "$TEMP_SSH/etc/ssh/ssh_host_ed25519_key"
  chmod 600 "$TEMP_SSH/etc/ssh/ssh_host_ed25519_key"
  ```
3. `cat $TEMP_SSH/etc/ssh/ssh_host_ed25519_key.pub` and add that value to the `.sops.yaml` in this repo, constrain it to only caring about its own host secrets file.
4. `sops updatekeys` for the file/host you'll be deploying to.
5. Optionally, do steps similar to the ones above - creating user SSH keys to be deployed onto the machine.  Update the corresponding host secrets file with those keys, so they're deployed.  Also add new entries for them to the `.sops.yaml` because ideally the user can edit all other secrets files.
  ```
  TEMP_USER_SSH=$(mktemp -d)
  ssh-keygen -t ed25519 -f "$TEMP_USER_SSH/etc/ssh/ssh_host_ed25519_key"
  ```
2. Boot the target machine using the liveUSB.
3. Change to `root`: `sudo su`
4. Set a password: `passwd`
5. Note the target machine's ip address: `ip addr`
6. From a remote machine, SSH into the target machine, for running the following steps.
7. `sudo gdisk /dev/nvme0n1`
8. We'll need a boot partition (ESP), a swap partition, and a large partition for NixOS (the type will be "8300" "Linux filesystem").  (Presuming that the boot and swap partitions have already been set up.)
9. Get the device IDs (ls /dev/disk/by-id/) and set them as variables like:
  ```
  BOOT=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part1
  SWAP=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part7
  DISK=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145827A-part8
  ```
10. Create the pool: `zpool create -o ashift=9 -o autotrim=on -O compression=zstd-9 -O mountpoint=none -O canmount=off -O xattr=sa -O acltype=posix -O dnodesize=auto -O atime=off -O normalization=formD rpool $DISK`
  * This SSD claims (`sudo fdisk -l`) 512 bytes as its ideal sector size, so going with `ashift=9`, even though `12` is the typical recommendation and often even `13` for SSDs.
  * `compression=zstd-9`: probably too much.  `on`/`lz4` is a no-brainer.  `zstd-3` is the default.  Cranking up the compression ratio this high might bottleneck on the CPU, rather than bottle-necking on reading off the NVME SSD.
  * `dnodesize=auto`
  * `atime=off`: disable writing the "access time" for every file read.
  * `normalization=formD`: something about using UTF-8 for filenames, and using the formD algorithm for comparison - which seems vaguely broadly compatible.
11. Create filesystems:
  ```
  zfs create -o canmount=noauto rpool/root
  zfs create rpool/home
  zfs create rpool/nix
  zfs create rpool/var
  ```
12. Mount those filesystems:
  ```
  mount -o X-mount.mkdir -o zfsutil -t zfs rpool/root /mnt
  mount -o X-mount.mkdir -o zfsutil -t zfs rpool/home /mnt/home
  mount -o X-mount.mkdir -o zfsutil -t zfs rpool/nix /mnt/nix
  mount -o X-mount.mkdir -o zfsutil -t zfs rpool/var /mnt/var
  mount -o X-mount.mkdir $BOOT /mnt/boot
  swapon $SWAP
  ```
13. Deploy. In a separate terminal, on the remote machine run (notice the `TEMP_SSH`, using the value from step #2 above):
  ```
  nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./hosts/thenixbeast/facter.json --extra-files "$TEMP_SSH" --phases kexec,install,reboot --flake .#thenixbeast --target-host root@<ip address>
  ```

## tailscale

Once tailscale is installed and running on your system, join the network by:
1. Run `tailscale up --login-server=https://headscale.immortalkeep.com`
2. Via a connection to the headscale server, run the command it gives you to register the node.  In this case, we're going to do so using kubectl:
  a. Find/confirm which username to register the node under: `kubectl exec -n apps headscale-abcdef-0123 -- headscale users list`
  b. `kubectl exec -n apps headscale-abcdef-0123 -- headscale nodes register --user {username_from_above} mkey:0123456789abcdef...`


## Deprecated dotfiles:
* chunkwm: project is no longer developed.  Move to `yabai` instead.
* fish: configuration moved to `home.nix`, now ceasing to maintain the `fish` directory.
* termite: terminal deprecated.  Author recommends using `alacritty` instead.
* uzbl: author last updated it in 2016.  Move to `qutebrowser` instead.
* zsh: ceasing to maintain the configuration files.  `fish` has all the shell niceness, batteries included.
