# TextyMcSpeechy - Docker Development branch

## This branch is not entirely complete but all the code needed for training models is finished and ready to use.

# Things that are ready to use in this branch
 - Dockerfile
 - docker-compose.yml
 - All scripts in `tts_dojo` have been refactored to use the `textymcspeechy-piper` docker container.
 - if the docker image has been built, `run_training.sh` will automatically bring  and take it down when it closes.
 - If you can build the docker image and install the dependencies listed in `setup.sh` the scripts in the `tts_dojo` directory are all ready to use.
 - every script will need to be made executable (`chmod +x *.sh`) in tts_dojo, tts_dojo/scripts, tts_dojo_scripts/utils, tts_dojo/DATASETS, and tts_dojo/PRETRAINED_CHECKPOINTS.   This will need to be done manually until `setup.sh` is finished.
 
 
## Things that are not finished yet
 - `setup.sh` is unfinished and parts of it are currently disabled.
 - I haven't uploaded a prebuilt docker image yet so you would need to build it yourself with the provided files.
 - The docs will need an overhaul to explain how to install docker, install CUDA related dependencies, build the image, shut down the image manually, etc.

 

