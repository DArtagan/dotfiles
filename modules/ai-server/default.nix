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
        "/mnt/mamba/ai/ollama:/root/.ollama"
      ];
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
    };

    open-webui = {
      image = "ghcr.io/open-webui/open-webui:main";
      autoRemoveOnStop = true;
      autoStart = true;
      environment = {
        WEBUI_AUTH = "False";
        AUDIO_STT_ENGINE = "openai";
        AUDIO_STT_OPENAI_API_BASE_URL = "http://speaches:8000/v1";
        AUDIO_STT_OPENAI_API_KEY = "does-not-matter";
        AUDIO_STT_MODEL = "Systran/faster-distil-whisper-large-v3";
        AUDIO_TTS_ENGINE = "openai";
        AUDIO_TTS_OPENAI_API_BASE_URL = "http://speaches:8000/v1";
        AUDIO_TTS_OPENAI_API_KEY = "does-not-matter";
        AUDIO_TTS_MODEL = "speaches-ai/Kokoro-82M-v1.0-ONNX";
        AUDIO_TTS_VOICE = "am_santa";
      };
      ports = [ "3000:8080" ];
      pull = "newer";
      volumes = [
        "/mnt/mamba/ai/open-webui:/app/backend/data"
      ];
    };

    speaches = {
      image = "ghcr.io/speaches-ai/speaches:latest-cuda";
      autoRemoveOnStop = true;
      autoStart = true;
      ports = [ "11435:8000" ];
      pull = "newer";
      volumes = [
        "/mnt/mamba/ai/speaches:/home/ubuntu/.cache/huggingface/hub"
      ];
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
    };
  };
}
