# Note - experimental, work in progress.

```
version: "3.9"

services:
  # Wyoming Piper TTS
  piper:
    image: rhasspy/wyoming-piper:latest
    container_name: wyoming-piper
    restart: unless-stopped
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
    command: --voices-dir /voices --host 0.0.0.0 --port 10200
    volumes:
      - ./voices:/voices
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
    networks:
      - wyoming

  # Wyoming Faster-Whisper STT
  whisper:
    image: rhasspy/wyoming-whisper:latest
    container_name: wyoming-whisper
    restart: unless-stopped
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
    command: --model large-v2 --host 0.0.0.0 --port 10300 --cuda
    volumes:
      - ./models:/models
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
    networks:
      - wyoming

  # OpenWakeWord Wake Word Engine
  openwakeword:
    image: rhasspy/wyoming-openwakeword:latest
    container_name: wyoming-openwakeword
    restart: unless-stopped
    command: --preload --model-dir /models --host 0.0.0.0 --port 10400
    volumes:
      - ./wakeword-models:/models
    networks:
      - wyoming

networks:
  wyoming:
    driver: bridge

```
