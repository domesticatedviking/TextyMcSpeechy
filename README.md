# TextyMcSpeechy - Docker Development branch

## This branch is not entirely complete but all the code needed for training models is finished and ready to use.

# Things that are ready to use in this branch
 - Dockerfile
 - docker-compose.yml
 - All scripts in `tts_dojo` have been refactored to use the `textymcspeechy-piper` docker container.

 
## Things that are not finished yet
 - `setup.sh` is unfinished and should not be used yet.
 - I am still quite new to docker and don't know whether I will need to update the dojo scripts to use the prebuilt container.  Will update after testing.
 


## The beginnings of an installation guide (WIP)
1.  Check for currently installed Nvidia driver by running `nvidia-smi`.  If something like the image below shows up, you may be able to skip to step 3.
![image](https://github.com/user-attachments/assets/d8d9c650-971c-427b-952e-8774f520f9e0)
2.  If Nvidia drivers are not installed on your system I recommend you do this using whatever "official" method exists for the distribution you are using.  That's all the advice I can give you - I have spent many hours repairing my distribution after installing a driver I shouldn't have.  If you survive move to step 3.
3.  Check whether docker is installed on your system by running `docker --version`.  If it is installed skip to step 5.
4.  You can install Docker using the instructions here: https://docs.docker.com/engine/install/
5.  You will need the NVIDIA Container toolkit to enable GPU access within docker containers.  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
6.  Clone this repo and switch to the docker-dev branch.  This will do both things: 
```
git clone -b docker-dev https://github.com/domesticatedviking/TextyMcSpeechy
```
7.  You can either download a prebuilt image of the `textymcspeechy-piper` docker container, or build the image yourself using the provided `Dockerfile` and `docker-dev.yml` file.
    - To build your own image, run the following command from the main `TextyMcspeechy` directory:  `docker compose build`
    - (Not yet integrated with the dojo scripts): To download the prebuilt image, run `docker image pull domesticatedviking/textymcspeechy-piper:latest`  Beware that this is quite a large download (~6GB compressed).
8. There are a few dependencies that need to be installed on the host to train models: `tmux`, `ffmpeg`, `sox` and `inotify-tools`.  
```
sudo apt-get update
sudo apt-get install tmux ffmpeg sox inotify-tools
```
9. Every script will need to be made executable (`chmod +x *.sh`) in `tts_dojo`, `tts_dojo/scripts`, `tts_dojo_scripts/utils`, `tts_dojo/DATASETS`, and `tts_dojo/PRETRAINED_CHECKPOINTS`.   This will need to be done manually until the setup script `setup.sh` is finished.
10. That should be pretty much the entire installation process.
11. `run_training.sh`  automatically runs the container when you start training and shuts it down when training ends. I don't recommend manually starting the container as this could result in permission issues on files shared between the host and container.
12. Usage is essentially the same as described on the `main` branch.
  
    




 

