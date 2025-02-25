# Note - experimental, work in progress.


# piper-gpu-hass docker-compose.yml
```
services:
  piper-gpu-hass:
    image: lscr.io/linuxserver/piper:gpu
    runtime: nvidia
    hostname: piper-gpu
    container_name: piper-gpu-hass
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - PIPER_VOICE=en_US-lessac-medium
      - PIPER_LENGTH=1.0 #optional
      - PIPER_NOISE=0.667 #optional
      - PIPER_NOISEW=0.333 #optional
      - PIPER_SPEAKER=0 #optional
      - PIPER_PROCS=1 #optional
    volumes:
      - /path/to/custom_piper_voices:/config
    ports:
      - 10200:10200
    restart: unless-stopped
```

# faster-whisper-gpu-hass docker-compose.yml
```
services:
  faster-whisper-gpu-hass:
    runtime: nvidia
    image: lscr.io/linuxserver/faster-whisper:gpu
    hostname: whisper-gpu
    container_name: faster-whisper-gpu-hass
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - WHISPER_MODEL=tiny-int8
      - WHISPER_BEAM=1 #optional
      - WHISPER_LANG=en #optional
    volumes:
      - /path/to/faster_whisper_data:/config
    ports:
      - 10300:10300
    restart: unless-stopped

```

(Change volumes in both files to point to a local folder on the host which will contain your custom voices / whisper models).   The part of the path after the colon is the path inside the docker container.



https://www.slacker-labs.com/setup-a-raspberry-pi-zero-2-w-as-a-wyoming-satellite/


There are some commands that fail in the above
```
#this worked to get the prebuilt apps to install
.venv/bin/pip3 install-f 'https://synesthesiam.github.io/prebuilt-apps/' -e '.[all]'
```
source of correction above:
https://github.com/rhasspy/wyoming-satellite/blob/f86d236432f3c28ac29594799cfe159ce1407cd9/docs/tutorial_2mic.md
