_: {
  stylix = {
    enable = true;
    targets = {
      firefox = {
        enable = false;
      };
      wayprompt.enable = false; # TODO: remove once nix-community/stylix#2557 merges and stylix is updated; it turns this option into an error
    };
  };
}
