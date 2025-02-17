# TextyMcSpeechy - Docker Development branch

### This branch is now feature complete!

## Done:
 - All scripts in `tts_dojo` have been refactored to use the `textymcspeechy-piper` docker container.
 - A prebuilt image of the docker container is now up on dockerhub.
 - `Dockerfile` and `docker-compose.yml` are provided if you want to run a locally built container
 - `setup.sh` now works
 - Added support for custom `espeak_ng` rules to be applied automatically whenever the container runs - more details [here](tts_dojo/ESPEAK_RULES/README_custom_pronunciation.md)
 - Install instructions are below

## To do:
 - tighten up the docs for this branch.
 - test install process
 - get feedback from users on how this is working for them
 - make this branch the new main branch
 

## Installation 
1.  Check for currently installed Nvidia driver by running `nvidia-smi`.  If something like the image below shows up, you may be able to skip to step 3
![image](https://github.com/user-attachments/assets/d8d9c650-971c-427b-952e-8774f520f9e0)
2.  If Nvidia drivers are not installed on your system I recommend you do this using whatever "official" method exists for the distribution you are using.  That's all the advice I can give you - In the past I have known the pain of spending hours repairing my OS after installing a driver I shouldn't have.  If you survive this step continue to step 3.
3.  Check whether docker is installed on your system by running `docker --version`.  If it is installed skip to step 5.
4.  You can install Docker using the instructions here: https://docs.docker.com/engine/install/
5.  You will need the NVIDIA Container toolkit to enable GPU access within docker containers.  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
6.  Clone this repo and switch to the docker-dev branch.  The command below will accomplish both: 
```
git clone -b docker-dev https://github.com/domesticatedviking/TextyMcSpeechy
```
7. Run `sudo bash setup.sh`  to install packages, make scripts executable, choose the type of container you wish to run, and verify that needed tools are installed.
8. Installation is complete.  If you chose to use the prebuilt container from dockerhub it should download automatically the first time you use the `run_container.sh` script. Take note that it's a 6GB download and over 10GB when decompressed.
9. The TTS Dojo script `run_training.sh`  automatically runs the `textymcspeechy-piper` container by calling `run_container.sh`when you start training and shuts it down when you end the training session.
10. Read the [quick start guide](quick_start_guide.md) to learn how to begin training models.


## Notes

- You can either download a prebuilt image of the `textymcspeechy-piper` docker container, or build the image yourself using the provided `Dockerfile` and `docker-dev.yml` file.
    - To build your own image, run the following command from the main `TextyMcspeechy` directory:  `docker compose build`
    - To download the prebuilt image manually, run the command below.
```
docker image pull domesticatedviking/textymcspeechy-piper:latest
```

 - Scripts are provided for launching the `textymcspeechy-piper` image, whether it is prebuilt or locally built.
    - `local_container_run.sh` launches images you have built yourself with `Dockerfile` and `docker-compose.yml`
    - `prebuilt_container_run.sh` launches a prebuilt image.
    - `run_container.sh` is a script that functions as an alias to one of the scripts above.  It is called by `run_training.sh` to automatically bring the container up when training starts.  
 
## Useful Guides in this repo:

 - [Using custom voices in Home Assistant](docs/using_custom_voices_in_home_assistant_os.md)
 - [Rendering custom voices for Home Assistant on a networked device with a GPU](docs/running_custom_piper_voices_on_GPU.md)




 

