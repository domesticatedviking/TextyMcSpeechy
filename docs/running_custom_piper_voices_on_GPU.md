# A guide for running a networked / GPU accelerated docker container to speed up TTS responses in Home Assistant.
## NOTE: This is a work in progress.  More details are coming.
For conversational AI apps, a Raspberry pi just isn't fast enough to render long TTS phrases in real time without long pauses before a response begins.  If you have a computer on your network with a GPU, you can use it to speed things up dramatically.   When running Piper on GPU, response latency becomes comparable to Alexa or Google Assistant.  If you don't have a dedicated GPU you will still see a major speed boost by running a piper docker container on a faster computer.


## Part 1: Setting up a docker container with Piper and Wyoming Protocol
1. Install Docker on a computer with a Nvidia GPU or faster CPU than your home assistant server.
2. Give thanks to the creators of this repo [https://github.com/linuxserver/docker-piper] 
3. Prepare your custom voice files [as required by Piper](renaming_and_preparing_custom_piper_voices.md). 
4. Make sure your host machine has a local IP address that won't change.  (Set up a DHCP reservation in your router's admin menu or use a static IP).  You will need this ip address later, so make a note of it.
5. Create a folder to hold the files that will be used to create the docker container and store the custom voice files: `/path/to/piper_gpu`. 
6. Create a folder inside `/path/to/piper_gpu` called `custom_voices`
7. Copy your [properly renamed](renaming_and_preparing_custom_piper_voices.md) `.onnx` and `.onnx.json` files to `/path/to/piper_gpu/custom_voices/`
8. Create the `docker-compose.yml` file below in your favorite text editor.  Edit the path in the `volumes:` section so that it points to your `custom_voices` folder.  It is important that this line ends with `:/config`
   -  This  maps a folder on your host machine `/path/to/piper_gpu/custom_voices/` to a folder inside the docker container `/config`
   -  The docker container may need to be restarted before it sees any voices you add to the `custom_voices` folder.
   -  The variables in `environment:` will be used as defaults but can be overridden from within Home Assistant.
   -  To run the container on your CPU instead of GPU, use `lscr.io/linuxserver/piper` on the `image:` line instead
   
```
# docker-compose.yml  <- Don't include this line in your file.

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
8. Save the file above to `piper_gpu/docker-compose.yml`
9. On your first run, the container will need to be created. To do this, from inside your `piper_gpu` folder, run:

```
docker-compose -f docker-compose.yml build --no-cache
```

10. To run your container:
```
docker-compose -f docker-compose.yml up -d
```

11. You can view any logs or error messages created by your container as follows:
```
docker compose -f docker-compose.yml logs -f
```

12. To verify that your container is running:
```
docker container ps
```

## Part 2: Connecting Home Assistant to your running docker container
1. Install the Wyoming Protocol integration if it isn't installed already.
2. If it is already installed, click the ADD SERVICE button
      -  In the `Host` field, use the IP address of the computer running your docker container. (eg 192.168.1.xxx).
      -  In the `Port` field, use `10200` (or whatever port you configured for piper to use in the docker container)
3. In the Wyoming protocol integration menu, optionally change the entity name to `piper_gpu` by clicking the `1 entity` link, then click the piper entity on the following screen, in the dialog box that appears, click the gear icon, then change the `Entity id` to `tts.piper_gpu` and click `update`.

## Part 3: Using custom voices on your GPU-accelerated piper docker container

1. Use [this guide](home_assistant_custom_voice_scripts.md) to create service scripts for any of the custom voices that exist in `/path/to/piper_gpu/custom_voices/`  
    - Filenames are case-sensitive and must match exactly.  Omit the `.onnx` extension when referring to piper voices in scripts.
    - Take care to use the correct entity (eg `tts.piper_gpu`) for the `entity_id`.
2. Provided your docker container is running properly, you can use your custom voices just like you would if they were running on the same machine as Home Assistant. The only real difference is the name of the service script you use to call them, and the fact that the output will be ready much, much faster.
    
    


