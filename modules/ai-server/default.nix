_: {
  # Requires modules/containers to also be loaded
  # Essentially a clone of github:DArtagan/ai-server/docker-compose.yaml

  virtualisation.oci-containers.containers = {
    ollama = {
      image = "ollama/ollama";
      autoRemoveOnStop = true;
      autoStart = true;
      ports = [ "11434:11434" ];
      pull = "newer";
      volumes = [
        "/mnt/mamba/ollama:/root/.ollama"
      ];
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
    };

    open-webui = {
      image = "ghcr.io/open-webui/open-webui:main";
      autoRemoveOnStop = true;
      autoStart = true;
      environment = {
        WEBUI_AUTH = "False";
      };
      ports = [ "3000:8080" ];
      pull = "newer";
      volumes = [
        "/mnt/mamba/open-webui:/app/backend/data"
      ];
    };
  };
}
