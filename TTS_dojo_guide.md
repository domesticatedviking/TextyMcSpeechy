# TTS Dojo

The TTS Dojo is a simplified workflow for changing the voice of text-to-speech models using [rhasspy/piper](https://github.com/rhasspy/piper).


## Notes before we begin
1. Piper must be installed before you can use the dojo.
1. The scripts assume that your `.venv` directory will be located in `/piper/src/python`. You will need to edit `PIPER_PATH` in `newdojo.sh` to point to the directory where you cloned the piper repo if this is not the case.
3. `tts_dojo/DOJO_CONTENTS` is the directory structure that will be cloned for each model you train.  Don't change the contents of this folder unless you know what you're wanting to accomplish.


## Gathering your training files.
You will need: 
- a dataset for your target voice consisting of a collection of `wav` files and a `metadata.csv` file containing the transcripts.
- a checkpoint file `.ckpt` of a [partially trained text-to-speech model](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main).
- see [README.md](README.md) if you need more detailed instructions.
- the dataset will be copied into the `target_voice_dataset` directory
- the `.ckpt file` will be copied into the `pretrained_tts_checkpoint` directory.
- For simplicity, you can copy `wav`, `*.ckpt`, and `metadata.csv` into `tts_dojo/MY_FILES` and use `add_my_files.sh` to move them into the expected locations once your dojo is created.

## Usage
1. Make sure your python venv is activated eg `source ./.venv/bin/activate`
2. run `newdojo.sh <VOICE_NAME>` to create the directory structure (inside `<VOICE_NAME>_dojo`)  for the components of your new model.
3. `cd <VOICE_NAME>_dojo`
4. If you copied your training files into `tts_dojo/MY_FILES` you can run `add_my_files.sh` to move them into the expected folders.  You can also use `add_my_files.sh /path/to/<somedir>` to populate your dojo from a different directory.
5. Run `start_training.sh`.  This script will automatically preprocess your training files, morph the pre-trained model to sound like the target voice, and generate the `yourvoice.onnx` and `yourvoice.onnx.json` voice files that piper uses.
6. IMPORTANT: Training can take a long time (minutes to hours).  This script cannot determine when your model is sufficiently trained, so you will need to to manually end training when you believe that your model is sufficiently trained by pressing <CTRL>C.
7. You will know training is working when you see the epoch numbers increasing in the file names of `EPOCH=nnnnn.ckpt` files in the output.
8. ~100 epochs of training should be sufficient to make the pretrained model sound like the target voice.
9. If you would prefer a more data-driven approach to knowing when your model is trained, open a second terminal window while training is in progress and run `view_training_progress.sh` to launch the tensorboard server and open  [http://localhost:6006/](http://localhost:6006/) in your web browser.  When the graph for "loss_disc_all" levels off, your model is ready.
10. After you stop training, your finished model will be created in `tts_dojo/<voicename>_dojo/finished_tts_voice/<voicename>`
11. Listen to your new voice:
```
    echo 'Thank you. Thank you very much!' | piper -m /path/to/yourvoice.onnx --output_file testaudio.wav
    aplay testaudio.wav  # or play it using any other player you like
```

## TODO:
- currently the only way to change training parameters and sampling rates is to edit the the scripts in `yourvoice_dojo/scripts`.
  


