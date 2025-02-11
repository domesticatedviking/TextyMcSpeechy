# A guide for running a GPU accelerated docker container to speed up responses in Home Assistant.
## NOTE: WORK IN PROGRESS

Steps:

1. Install Docker
2. Give thanks to the creators of this repo [https://github.com/linuxserver/docker-piper] 
3. Rename your custom voice files as required by Piper.
4. Create a folder for to hold the files that will be used to create the docker container `/path/to/piper_gpu`
5. Create a folder inside `/path/to/piper_gpu` called `custom_voices`
6. Copy your properly renamed `.onnx` and `.onnx.json` files to `/path/to/piper_gpu/custom_voices/`
7. Create the `docker-compose.yml` file below in your favorite text editor.  Edit the path in the `volumes:` section so that it points to your `custom_voices` folder.  It is important that this line ends with `:/config`
   -  This  maps a folder on your host machine `/path/to/piper_gpu/custom_voices/` to a folder in the docker container `/config`
   -  The docker container may need to be restarted before it sees any voices you add to the `custom_voices` folder
   -  The variables in `environment:` will be used as defaults but can be overridden from within Home Assistant.
   
```
# docker-compose.yml  

services:
  piper:
    image: lscr.io/linuxserver/piper:gpu
    container_name: piper
    environment:
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
      - /path/to/piper_gpu/custom_voices/:/config
    ports:
      - 10200:10200
    restart: unless-stopped

```
