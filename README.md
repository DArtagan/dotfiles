# dotfiles & system configuration

## Nix
Nix configuration is using this approach as its spirit guide: https://github.com/Baitinq/nixos-config

### Update the system

One should first make sure all changes are committed to the repo.
```
nix flake update
sudo nixos-rebuild switch --flake .
```

## Binary caches

Substituters are set in `configuration.nix` (`nix.settings`). Nix tries them in priority order:

| Cache | Priority | Purpose |
|---|---|---|
| `https://cache.nixos.org` | 40 | Upstream. |
| `http://mini-nas.forge.local:8770/public` | 41 | Attic on mini-nas. mini-nas's post-build-hook pushes its builds here. Paths expire 6 months after last access (server default). |
| `http://mini-nas.forge.local:8770/archive` | 50 | Attic on mini-nas, **garbage collection disabled** (retention 0). For store paths that must never disappear, such as sources whose upstream was withdrawn. |

### `archive`: keeping a package whose source vanished

If upstream deletes its source, a package can still build as long as its fixed-output paths (the `src`, plus things like `cargoDeps`/`npmDeps`) can be substituted by hash. Keep the old `hash`/`cargoHash`, and make sure those paths live in `archive`. Current contents:

- **qbz 2.0.2** (`pkgs/qbz`, removed from nixpkgs 2026-09-18 after the author withdrew it):
  `/nix/store/2jfmb3dj1l1sc7pf6gca0vsczdkrikpi-source`, `/nix/store/ww0rw91wr6cgyjcpzg3zwr0vz8xikh30-qbz-2.0.2-vendor`

To add paths (Attic server config lives in the mini-nas repo, `modules/attic`):

1. Make sure the paths are local: `nix-store --realise <path>...` (they're usually still on cache.nixos.org).
2. You need a token with push access to `archive`. The everyday `mini-nas` token in `~/.config/attic/config.toml` can't do this. Mint a short-lived one on mini-nas and log in under a separate name:
   ```bash
   sudo atticd-atticadm make-token --sub will --validity 1d --push archive --pull archive
   attic login mini-nas-admin http://mini-nas.forge.local:8770 <token>
   ```
3. Push. `--ignore-upstream-cache-filter` is **required**: the cache lists `cache.nixos.org-1` as upstream, so without the flag Attic silently skips anything cache.nixos.org has signed.
   ```bash
   attic push --ignore-upstream-cache-filter mini-nas-admin:archive <path>...
   ```
4. Verify: `nix path-info --sigs --store http://mini-nas.forge.local:8770/archive <path>...` should list each path with an `archive:` signature.
5. Record the paths in the list above, then remove the `[servers.mini-nas-admin]` block from `~/.config/attic/config.toml`.

If a push fails:
- **Times out after about 30 s, and atticd logs `Connection pool timed out`:** SQLite has no query statistics. It picks `idx-chunk-state-holders` instead of `idx-chunk-chunk-hash`, and every chunk lookup scans about 1.5M rows. Fix it on mini-nas: stop atticd, `sqlite3 /var/lib/private/atticd/server.db` console run `ANALYZE;`, then start atticd again. First fixed 2026-09-21.
- **Fails with a fast 500, and atticd logs `database is locked`, right after atticd restarts:** atticd runs a GC pass on startup that holds the write lock. Wait until `server.db-wal` stops growing, then retry.

The cache was created with `attic cache create …:archive --public` and `attic cache configure …:archive --priority 50 --retention-period 0s`. Its public key, `archive:1X1f2tklkN82QbeLjMYnySG9zhP+fWJsBSjK9Y6tPrY=`, is in `trusted-public-keys`.

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
  ssh-keygen -t ed25519 -f "$TEMP_USER_SSH/id_ed25519"
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
  b. `kubectl exec -n apps headscale-abcdef-0123 -- headscale nodes register --user {username_from_above} --key mkey:0123456789abcdef...`
3. You may also want to rename the node in headscale:
  a. Get the numeric ID of the node: `kubectl exec -n apps headscale-abcdef-0123 -- headscale nodes list`
  b. Using the numeric ID as the index, give the node a new name: `headscale nodes rename -i 7 new-name`


## Wifi

1. List network interfaces: `nmcli device`
2. List nearby networks: `nm device wifi list`
3. Connect: `nm device wifi connect {network_name} --ask`
4. Disconnect: `nm device disconnect {wifi_interface_name}`


## Deprecated dotfiles:
* chunkwm: project is no longer developed.  Move to `yabai` instead.
* fish: configuration moved to `home.nix`, now ceasing to maintain the `fish` directory.
* termite: terminal deprecated.  Author recommends using `alacritty` instead.
* uzbl: author last updated it in 2016.  Move to `qutebrowser` instead.
* zsh: ceasing to maintain the configuration files.  `fish` has all the shell niceness, batteries included.
