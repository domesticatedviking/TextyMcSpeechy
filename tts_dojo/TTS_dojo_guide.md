# TTS Dojo

The TTS Dojo is a simplified workflow for changing the voice of text-to-speech models using [rhasspy/piper](https://github.com/rhasspy/piper).



## UPDATE MAY 18 2024:
### Significant upgrade to TTS dojo scripts
- Automatic sampling rate detection
- Dataset file format verification 
- Automatically convert non-wav audio files to .wav
- Automatic batch resampling
- Auto-configure max-workers for piper preprocessing to avoid errors (see closed issue 2)
- Auto-configure sampling rate in training scripts
- Run tensorboard server concurrently with training via tmux
- Tidier output
### Known issues:
- Packaging of onnx files currently always selects the checkpoint file in lightning_logs/version_0
   - This will be fixed as part of my plan to give the dojo the ability to preview and compare multiple checkpoints of the same voice.







## Notes before we begin
1. Piper must be installed before you can use the dojo. I recommend using `install_piper.sh` to ensure everything ends up in the expected locations.
2. `tts_dojo/DOJO_CONTENTS` is the directory structure that will be cloned for each model you train.  Don't change the contents of this folder unless you know what you're wanting to accomplish.
3. Piper expects datasets that have sampling rates of either 16000Hz or 22050Hz.  Care must be taken to ensure that the sampling rate of the dataset is the same one used by the pretrained text-to-speech `.ckpt` file. Use 16000Hz for x-low and low pretrained piper models, and 22050Hz for medium and high models.



## Gathering your training files.
You will need: 
- a dataset for your target voice consisting of a collection of `wav` files and a `metadata.csv` file containing the transcripts.
- a checkpoint file `.ckpt` of a [partially trained text-to-speech model](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main).
- see [README.md](README.md) if you need more detailed instructions.
- the dataset will be copied into the `target_voice_dataset` directory
- the `.ckpt file` will be copied into the `pretrained_tts_checkpoint` directory.
- For simplicity, you can copy `wav`, `*.ckpt`, and `metadata.csv` into `tts_dojo/MY_FILES` and use `add_my_files.sh` to move them into the expected locations once your dojo is created.

## Usage
1. Make sure your python venv is activated eg `source piper/src/python/.venv/bin/activate`
2. `cd tts_dojo`
3. run `newdojo.sh <VOICE_NAME>` to create the directory structure (inside `<VOICE_NAME>_dojo`)  for the components of your new model.  Note: newdojo.sh stores several paths in hidden files inside the dojo folder.  If you move your dojo folder to another location after creating it, the scripts will not work unless you manually update the paths in `.BIN_DIR`, `.DOJO_DIR`, and `.PIPER_PATH`.
4. `cd <VOICE_NAME>_dojo` 
5. If you copied your training files into `tts_dojo/MY_FILES` you can run `add_my_files.sh` to move them into the expected folders.  You can also use `add_my_files.sh /path/to/<somedir>` to populate your dojo from a different directory.
6. Run `start_training.sh`.  This script will automatically preprocess your training files, morph the pre-trained model to sound like the target voice, and generate the `yourvoice.onnx` and `yourvoice.onnx.json` voice files that piper uses.
7. IMPORTANT: Training can take a long time (minutes to hours).  This script cannot determine when your model is sufficiently trained, so you will need to to manually end training when you believe that your model is ready. 
8. You will know training is working when you see the epoch numbers increasing in the file names of `EPOCH=nnnnn.ckpt` files in the output.
9. ~100 epochs of training should be sufficient to make the pretrained model sound like the target voice.  Edit: I am still experimenting with this.  Elsewhere I have seen recommendations of 1000 epochs. 
10. If you would prefer a more data-driven approach to knowing when your model is trained, while training is in progress open tensorboard [http://localhost:6006/](http://localhost:6006/) in your web browser.  When the graph for "loss_disc_all" levels off, your model is probably almost ready.
11. The latest version of the dojo scripts use `tmux` to run training and the tensorboard server in a split screen.   If you accidentally close the script in the bottom pane, you will need to shut down the server manually by running `tmux kill-session`.
12. After you stop training, your finished model will be created in `tts_dojo/<voicename>_dojo/finished_tts_voice/<voicename>`
13. Listen to your new voice:
```
    echo 'Thank you. Thank you very much!' | piper -m /path/to/yourvoice.onnx --output_file testaudio.wav
    aplay testaudio.wav  # or play it using any other player you like
```


## TODO:
- Provide menus to load and save user preferences for dataset sanitizer.
- Improve the dojo's awareness of data from prior training runs.
- Generate previews of the voice from intermediate checkpoints as the model trains.
- add epoch suffix to name and subfolder for final TTS models to allow them to coexist with models trained on earlier checkpoints.
- add option to automatically speak a test phrase when the model is done training
- add option to speak a test phrase in every incrementally trained TTS voice in the `finished_tts_voice` folder
  


