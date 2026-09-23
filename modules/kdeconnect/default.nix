# Clipboard (and ad-hoc file/notification) sync with phones.
#
# NixOS half: the package plus the firewall holes (TCP+UDP 1714-1764, opened by
# the upstream module). The daemon itself belongs to the user session — see
# ./hm.nix.
_: {
  programs.kdeconnect.enable = true;
}
