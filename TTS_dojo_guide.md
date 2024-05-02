# TTS Dojo

The TTS Dojo is a simplified workflow for training text-to-speech models using [rhasspy/piper](https://github.com/rhasspy/piper).
Piper must be installed before you can use the dojo.

# Files you will need to gather to use the dojo
- a dataset for your target voice consisting of a collection of `wav` files and a `metadata.csv` file containing the transcripts.
- a checkpoint file `.ckpt` of a [partially trained text-to-speech model](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main).
- see [README.md](README.md) if you need more detailed instructions.

### Instructions
1. run `./newdojo.sh <VOICE_NAME>  to create the directory structure (inside `<VOICE_NAME>_dojo`)  for the components of your new model.
2. Copy target voice dataset's `wav` directory and `metadata.csv` file into the `target_voice_dataset` directory.
3. copy your  `.ckpt file` into the `pretrained_tts_checkpoint` directory. 
4. run `bash 1_preprocess.sh` to prepare your dataset for training.
5. Verify that training parameters are set correctly by editing `2_train.sh`
6. run `bash 2_train.sh`  You will need to manually end the training session by pressing `<ctrl> C` when you think the model is ready. (100 epochs will usually be sufficient)
7. optionally, run `view_training_progress.sh` to launch the tensorboard server, and open [http://localhost:6006/](http://localhost:6006/) in your browser to monitor training progress.  Training can be stopped when the graph for "loss_disc_all" levels off.
8. run `bash 3_finish_voice.sh` to package your model into a form that Piper can use.
9. Look in the `finished_tts_voice` folder for your finished model

  
  


