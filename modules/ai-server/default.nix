{
  config,
  lib,
  pkgs,
  ...
}:
{
  options."ai-server".startAfter = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Systemd units that all ai-server container services should be ordered After=.";
  };

  options."ai-server".models = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "qwen3.6:27b" # Alibaba: primary agentic/tool-use + general reasoning driver
      "gpt-oss:20b" # OpenAI: fast, large-context, low-VRAM model for lighter/short tasks
      "gemma4:31b-it-qat" # Google: QAT int4 second-opinion reasoner (near-bf16 quality, fits 24GB)
      "mistral-nemo" # Mistral: natural prose / creative writing; many strong community finetunes exist
    ];
    description = "Ollama models to ensure are pulled on this host.";
  };

  config = {
    # Requires modules/containers to also be loaded
    # Essentially a clone of github:DArtagan/ai-server/docker-compose.yaml

    virtualisation.oci-containers.containers = {
      ollama = {
        image = "ollama/ollama";
        autoRemoveOnStop = true;
        autoStart = true;
        environment = {
          OLLAMA_FLASH_ATTENTION = "1";
          OLLAMA_KV_CACHE_TYPE = "q8_0";
          # Models support 128K-256K context, but Ollama defaults to 4096.
          # 32K is a realistic window on 24GB with the q8_0 KV cache.
          OLLAMA_CONTEXT_LENGTH = "32768";
        };
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

    systemd.services = lib.mkMerge [
      (lib.mkIf (config."ai-server".startAfter != [ ]) (
        lib.genAttrs [ "podman-ollama" "podman-open-webui" "podman-speaches" ] (_: {
          after = config."ai-server".startAfter;
          wantedBy = lib.mkForce [ "graphical.target" ];
        })
      ))

      # ollama and speaches request nvidia.com/gpu=all, so they need the CDI
      # spec at /run/cdi to exist. Order them After the generator so on a fresh
      # boot the spec is written before the container starts. Across a driver
      # update the generator is skipped but its spec is preserved (see
      # modules/containers), so these can restart and resolve the device against
      # the still-valid old spec with no downtime.
      (lib.genAttrs [ "podman-ollama" "podman-speaches" ] (_: {
        after = [ "nvidia-container-toolkit-cdi-generator.service" ];
      }))

      # Ensure the declared models are present. `ollama pull` is idempotent
      # (a no-op when already up to date), so this is safe on every boot. Wait
      # for the container's API before pulling to avoid racing its startup.
      (lib.mkIf (config."ai-server".models != [ ]) {
        ollama-pull-models = {
          description = "Pull declared Ollama models";
          after = [ "podman-ollama.service" ];
          requires = [ "podman-ollama.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            until ${pkgs.podman}/bin/podman exec ollama ollama list >/dev/null 2>&1; do
              sleep 2
            done
            ${lib.concatMapStringsSep "\n" (
              m: "${pkgs.podman}/bin/podman exec ollama ollama pull ${lib.escapeShellArg m}"
            ) config."ai-server".models}
          '';
        };
      })
    ];
  };
}
