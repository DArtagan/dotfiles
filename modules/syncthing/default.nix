{ config, lib, ... }:
let
  inherit (config.syncthing) username;
in
{
  options.syncthing.username = lib.mkOption {
    type = lib.types.str;
  };

  config = {
    services.syncthing = {
      enable = true;
      tray.enable = true;
      settings = {
        devices = {
          TheBeast_Manjaro.id = "XFBFA7U-QHO6RGW-6O5LUX3-4AFGAHF-477KYYN-NYPGRJ2-PDU35JO-GYBVJQG";
          TheBeast_Windows.id = "L7U3GPV-GBY3DGN-GSXIZH2-AO4S4A3-X36ENZW-ZPOOCTT-ZM5OERL-O7PNTAX";
          steamdeck.id = "6BVRFCL-FAEEMK4-P5WJTFF-BYL5OAD-WLTKDY6-GWPQYOM-4H4C4KA-5CJTYAT";
          thenixbeast.id = "SMAK544-FH76T3A-7TT2PRY-CJQOQUX-JQ2EGY2-HSOLSBW-TJYMWBB-D7IMBQ7";
          vulcanus = {
            id = "D7PP4ZM-3OIYCDC-2WOOMSO-K2F7WEI-3XA33XZ-TZJ66FK-DQLOZEG-HIZ7EA6";
            introducer = true;
          };
        };
        folders = {
          "dropbox" = {
            id = "rwt4c-vtghd";
            path = "/home/${username}/dropbox";
            devices = [
              "vulcanus"
              "TheBeast_Manjaro"
              "TheBeast_Windows"
              "steamdeck"
              "thenixbeast"
            ];
          };
          "ebooks" = {
            id = "ynwr5-igvw5";
            path = "/home/${username}/ebooks";
            devices = [
              "vulcanus"
              "TheBeast_Manjaro"
              "TheBeast_Windows"
              "steamdeck"
              "thenixbeast"
            ];
          };
          "projects" = {
            id = "hzhvg-z5atl";
            path = "/home/${username}/projects";
            devices = [
              "vulcanus"
              "TheBeast_Manjaro"
              "TheBeast_Windows"
              "steamdeck"
              "thenixbeast"
            ];
          };
          "school" = {
            id = "wkpyo-eeckc";
            path = "/home/${username}/school";
            devices = [
              "vulcanus"
              "TheBeast_Manjaro"
              "TheBeast_Windows"
              "thenixbeast"
            ];
          };
        };
        options = {
          relaysEnabled = true;
          urAccepted = 1;
        };
      };
    };
  };
}
