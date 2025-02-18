# TextyMcSpeechy

## Make any voice into a Piper text-to-speech model 
- Make a custom Piper TTS model out of your own voice samples or any existing voice dataset
- Learn how to convert a public domain dataset into another voice using an RVC model
- Learn how to make custom datasets from audio clips and text transcripts
- Use the dataset recorder to make fun TTS clones of your family and friends
- Listen to your voice as training progresses in a convenient training environment 
- Rapidly train custom TTS voices by finetuning pretrained checkpoint files
- Now runs Piper in a docker container for much more convenient installation
- Includes original resources for creating custom pronunciation rules.
- Includes original guides for using custom Piper voices with [Home Assistant](https://www.home-assistant.io/)
- 100% free, runs 100% offline.
  
## This hobby project has gotten real press!  How cool is that!?
- https://www.tomshardware.com/raspberry-pi/add-any-voice-to-your-raspberry-pi-project-with-textymcspeechy
- https://www.hackster.io/news/erik-bjorgan-makes-voice-cloning-easy-with-the-applio-and-piper-based-textymcspeechy-e9bcef4246fb

## News
- **February 18 2025** - A new main branch appears!
    - This brand new branch runs Piper in a docker container, which makes installation far, far, far, less painful.
    - The scripts and docs in this branch have all been overhauled.
    - The branch formerly known as `main` is now the `non-containerized` branch.  It will be kept around for reference purposes but will not be maintained.

## Usage

Read the [quick start guide](quick_start_guide.md) to learn how to build datasets and train models.

## Original guides in this repo:
 - [Customizing pronunciation](tts_dojo/ESPEAK_RULES/README_custom_pronunciation.md)
 - [Using custom voices in Home Assistant](docs/using_custom_voices_in_home_assistant_os.md)
 - [Rendering custom voices for Home Assistant on a networked device with a GPU](docs/running_custom_piper_voices_on_GPU.md)
 
## System Requirements
 - A NVIDIA GPU with drivers capable of running CUDA is required. Training on CPU, while technically possible, is not officially supported.
 - A hard drive with sufficient storage capacity for the base installation (~15GB) and checkpoint files generated during training.  50gb of free space is suggested as a practical minimum.
 - This project is written entirely in shell script and is primarily intended for Linux users.   Windows users will need to use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) to run it.

## Installation:
1.  Check for currently installed Nvidia driver by running `nvidia-smi`.  If something like the image below shows up, you may be able to skip to step 3
![image](https://github.com/user-attachments/assets/d8d9c650-971c-427b-952e-8774f520f9e0)
2.  If Nvidia drivers are not installed on your system I recommend you do this using whatever "official" method exists for the distribution you are using.  That's all the advice I can give you - in the past I have known the pain of spending hours repairing my OS after installing a driver I shouldn't have.  If you survive this step continue to step 3.
3.  Check whether Docker is installed on your system by running `docker --version`.  If it is installed skip to step 5.
4.  You can install Docker using the instructions here: https://docs.docker.com/engine/install/
5.  You will need the NVIDIA Container Toolkit to enable GPU access within docker containers.  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
6.  Clone this repo: 
```
git clone https://github.com/domesticatedviking/TextyMcSpeechy
```
7. From the `TextyMcSpeechy` directory, run `sudo bash setup.sh`  to install packages, make scripts executable, choose the type of container you wish to run, and verify that needed tools are installed.
8. Installation is complete.  If you chose to use the prebuilt container from dockerhub it will download automatically the first time you use the `run_container.sh` script or start to train a model. Take note that it's a 6GB download and over 10GB when decompressed.
9. Continue with the [quick start guide](quick_start_guide.md) to begin training models.




## Notes

- The prebuilt docker container will install automatically - You don't need to download it.  But if you want to anyway, run this:
```
docker image pull domesticatedviking/textymcspeechy-piper:latest
```
- To build your own image from the `Dockerfile` and `docker-compose.yml` in the main `TextyMcspeechy` directory, change to that directory and run:
```
docker compose build
```
 - Scripts are provided for launching the `textymcspeechy-piper` image, whether it is prebuilt or locally built.
    - `local_container_run.sh` launches images you have built yourself with `Dockerfile` and `docker-compose.yml`
    - `prebuilt_container_run.sh` launches a prebuilt image.
    - `run_container.sh` is a script that functions as an alias to one of the scripts above.  It is called by `run_training.sh` to automatically bring the container up when training starts.  

 - Custom `espeak-ng` pronunciation rules can be defined in `tts_dojo/ESPEAK_RULES`.  A guide for customizing pronunciation can be found [here](tts_dojo/ESPEAK_RULES/README_custom_pronunciation.md).
