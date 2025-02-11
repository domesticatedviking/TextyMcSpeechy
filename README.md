# TextyMcSpeechy

## A workflow with convenience scripts for making any voice into a Piper text-to-speech (TTS) model.
- Make a custom text-to-speech (TTS) model out of your own voice samples
- Make a custom TTS model out of any existing voice dataset
- Make a custom TTS model by converting a generic voice dataset into another voice using an RVC model.
- Rapidly train high quality TTS by using pretrained checkpoint files
- Preview your voice model while it is training and choose the best version of your voice.

## This hobby project has gotten real press!  How cool is that!?
- https://www.tomshardware.com/raspberry-pi/add-any-voice-to-your-raspberry-pi-project-with-textymcspeechy
- https://www.hackster.io/news/erik-bjorgan-makes-voice-cloning-easy-with-the-applio-and-piper-based-textymcspeechy-e9bcef4246fb

## February 2025: tutorials for using custom Piper voices within Home Assistant OS.
- I couldn't find a guide for using custom Piper voices in Home Assistant OS, so [I wrote my own](docs/using_custom_voices_in_home_assistant_os.md).
- A tutorial for creating a lovelace GUI for testing your custom voices can be found [here](docs/using_custom_voices_in_home_assistant_os.md).
- A tutorial for improving TTS response time by running Piper on a (GPU accelerated) docker container which supports custom voices is underway [here](docs/running_custom_piper_voices_on_GPU.md). 

## December 29 2024: Batch noise reduction script
- Added a script to the dataset recorder `remove_roomtone.sh` that automates the removal of background noise (roomtone) from dataset files.
- Requires `sox` to be installed and a short `.wav` sample of silence from the environment where the dataset was recorded.

## December 23 2024: Maintenance updates
- Fixed pip and numpy version issues that were causing  `install_piper.sh` to fail.  (pytorch-lightning requres pip<=24.0, piper can't preprocess datasets unless numpy<2.0.0)
- Fixed bug in `download_defaults.sh` that was causing downloads of pretrained checkpoint files to be named incorrectly


## May 27 2024:  New tool - Dataset recorder
- This is probably the fastest possible way to record a dataset, and is ideal for making a clone of one's own voice.
- `dataset_recorder.sh` takes any metadata.csv file as input and interactively records voice samples for every phrase it references under the proper file name.
- an ai generated sample `metadata.csv` file is included, but you will get better results using a `metadata.csv` file from a public domain academic dataset.  Phrases should be phonetically diverse, with a mix of short and longer phrases (ideally the phrase length should follow a normal distribution), and should include a mix of tonal pattterns (eg. statements, questions, exclamations).  If there are expressions or names you want to use in your target application, including variations of those phrases in the dataset multiple times is very beneficial to making your model sound as natural as possible.

## Installation
- The [quick-start guide](quick_start_guide.md) explains how to get TextyMcSpeechy set up.
- Do not use the manual installation steps described in the legacy guide.   Most of them have been automated.


## Recommended hardware and notes about performance
1. A PC running Linux which has a NVIDIA GPU is highly recommended / required for training.
2. Once TTS models are trained, they will run on much less powerful hardware, but Piper uses a neural network to generate speech.  This is a computationally expensive process which benefits from fast hardware.
3. A Raspberry Pi 5 should be considered the absolute minimum for rendering text-to-speech notifications in real time, however Home Assistant caches commonly used phrases which speeds things up significantly.   Conversational AI applications with long utterances will have unacceptable amounts of latency (eg 5-20 seconds) unless run on more powerful hardware.



# Description of the training process.

### Option A: convert a generic dataset into the target voice using an RVC model, then train TTS.

1. Install Piper
2. Install Applio
3. Experiment with Applio until you find the voice you wish to turn into a text-to-speech model
4. Get a training dataset (wav files with text transcriptions) for a person similar in tone/accent to the target voice.
5. Use Applio to batch-convert the audio files in the training dataset so that they sound like the target voice.
6. Prepare the converted dataset for use with Piper
7. Get a checkpoint `ckpt` file for an existing text-to-speech model similar in tone/accent to the target voice.
8. Use Piper to fine-tune the existing text-to-speech model using the converted dataset.
9. Convert the fine-tuned `.ckpt` file to a `.onnx` file that can be used by Piper directly to generate speech from text.
10. Test the new text-to-speech model.
- Note:  The main advantage of this method is that it is less work, provided you have a decent RVC model for your target voice. Most of the intonation will come from the voice in the original dataset, which means that this method isn't great for making characters with a dramatic intonation.   If you don't have access to samples of the target voice, you will get much more natural intonation by recording a base dataset that does your best impression of the target voice prior to applying the RVC model.


### Option B: train TTS using your own dataset (audio files in target voice and text transcript)
1. Install Piper 

 (skip steps 2,3,4,and,5)
 
6. Prepare the converted dataset for use with Piper
7. Get a checkpoint `ckpt` file for an existing text-to-speech model similar in tone/accent to the target voice.
8. Use Piper to fine-tune the existing text-to-speech model using the converted dataset.
9. Convert the fine-tuned `.ckpt` file to a `.onnx` file that can be used by Piper directly to generate speech from text.
10. Test the new text-to-speech model.
- Note:  The disadvantage of this method is that building a dataset can be a lot of work, but the quality of the resulting voices makes this work worthwhile.    I have built usable voice models with as few as 50 samples of the target voice.   This is the best method for building voices for characters that have very distinctive intonation. If catchphrases and distinctive expressions are part of the training dataset, when those phrases are used in the TTS engine they will sound almost exactly like the original voice.   If building a model out of your own voice, make sure to include the names of people and places that are significant to you in your dataset, as well as any phrases you are likely to use in your application.


# Legacy Guide: How to train a TTS model with Piper without the TTS Dojo.
#### Note: This guide was written before the TTS dojo existed.  It's still useful for understanding the steps involved, but the TTS Dojo automates many of these steps.
#### Follow the [quick-start guide](quick_start_guide.md) to install and configure the TTS dojo when you have a dataset and are ready to start training.
#### I will be taking this guide out of the main docs when I have time to write a replacement guide just for creating datasets.


## Step 1: Installing Piper

#### The TTS Dojo won't work if you install piper this way.  Use `install_piper.sh` instead.
1. `sudo apt-get install python3.dev`
2. `git clone https://github.com/rhasspy/piper.git`  
3. `cd piper/src/python`  (You will have an easier time if you put your venv in this directory)
4. `python3.10 -m venv .venv`  note - Torch needs python 3.10 and won't work on 3.11 without extra steps. 
5. `source ./.venv/bin/activate`
6. `pip install pip wheel setuptools -U`
7. `pip install --upgrade pip==24.0` (pytorch-lightning installation will fail without this downgrade to pip)
8. `pip install piper-tts`
9. `pip install build` 
10. `python -m build` 
11. `pip install -e .`
12. `pip3 install -r requirements.txt`
13. `pip install --upgrade numpy==1.23.5` (downgrade numpy to meet piper requirements)
14. `bash ./build_monotonic_align.sh`
15. `sudo apt-get install espeak-ng`
16. `pip install torchmetrics==0.11.4`  (this is a downgrade to avoid an error)

- Note: Installing the correct version of CUDA can be a hassle.   The easiest way to get an environment that works for Piper is to activate the .venv and run: `python3 -m pip install tensorflow[and-cuda]` (enter this command exactly as it appears here including the square brackets). It's also possible to install tensorflow without GPU support by running `python3 -m pip install tensorflow`.  I haven't tried training on CPU but would be interested to hear from anyone who has tried it.


## Step 2: Installing Applio
- Follow instructions here: [https://github.com/IAHispano/Applio](https://github.com/IAHispano/Applio)

## Step 3: Experiment with changing voices in Applio
- Applio has a nice gui - it isn't very hard to figure out
- Todo - write or link to a more comprehensive guide

## Step 4: Getting a training dataset
 Update: For an easy way to do this, see  [VCTK_dataset_tools/using_vctk_dataset.md](VCTK_dataset_tools/using_vctk_dataset.md)

1. A dataset is a collection of audio clips with matching text transcriptions.  There are many options available in the public domain, or you can record and transcribe your own voice.  A repo with many public domain datasets can be found here:  https://github.com/jim-schwoebel/voice_datasets
2. I have found https://vocalremover.org/ to be a useful tool for extracting voices from background music and other sounds. 
3. For voice cloning, it is best if the person speaking in the dataset has a voice similar in tone and accent to the target voice.  Keep in mind that some datasets include audio from multiple speakers.
4. Piper requires transcription data to be gathered into a single `metadata.csv` file, with one line per wav file in the following format:
   - `FILENAME` | `transcript`  is the form for single speaker datasets (if you are making your own transcripts, this is the format you should use)
   - `FILENAME` | `SPEAKER ID` | `transcript` is the form for multiple speaker datasets.  This format will also work for a single speaker dataset if the speaker ids are all the same.
5. I use a spreadsheet to create my csv file when transcribing my own datasets, but you can also create this file manually in any text editor.
6. It is not necessary to include the path or file extension (eg `.wav`) in the file names listed in in `metadata.csv`.
   
This is what the metadata.csv file I created from the VCTK dataset looks like.
```
p316_001_mic1_output|Please call Stella.
p316_002_mic1_output|Ask her to bring these things with her from the store.
p316_003_mic1_output|Six spoons of fresh snow peas, five thick slabs of blue cheese
```
- see [VCTK_dataset_tools](VCTK_dataset_tools/using_vctk_dataset.md) for some helpful scripts for generating metatata.csv if your dataset uses individual text files
- see the [dataset recorder](dataset_recorder) for a tool that will let you quickly record a dataset using your own voice.

## Step 5: Convert dataset into the target voice
- Convert all of the audio files in the dataset into the target voice using Applio.
- Batch conversion of a generic dataset into another voice can be done on the "Inference" tab.
- Select the Batch tab, choose a voice model, specify the location of your input and output folders, then click "Convert"

## Step 6: Preparing your dataset for use with Piper
### note: The [TTS Dojo](tts_dojo/TTS_dojo_guide.md) provides tools that automate this step.
1. Ensure that your audio files are all in  `wav` format with an appropriate sampling rate (22050 Hz or 16000 Hz) and kept together in a folder named `wav`.
   Batch conversion and resampling of flac files can be done with the following bash script:
```
for file in *.flac; do
    ffmpeg -i "$file" -ar 22050 "${file%.flac}.wav"
done
```
2. Find the piper repository you cloned earlier and `cd /path/to/piper/src/python`
3. Make sure your virtual enviroment is activated eg. `source ./.venv/bin/activate`
4. Make a directory for your dataset, eg `elvis_dataset`
5. Copy `metadata.csv` from step 4 and your `wav` folder into `elvis_dataset`
6. Make a directory for the training files eg `elvis_training`
7. Run the following:
   
```
python3 -m piper_train.preprocess  \
--language en-us \
--input-dir /path/to/elvis_training_dataset    \
--output-dir /path/to/elvis_training   \
--dataset-format ljspeech \  
--single-speaker   \
--sample-rate 22050 \
```
8. If preprocessing is successful, it will generate `config.json`, `dataset.jsonl`, and audio files in `elvis_training`
- Note: If preprocessing fails with a "not enough columns" error, this is usually because your `.csv` file has blank lines at the end. 

## Step 7: Get an existing text to speech model to fine-tune
### note: The [TTS Dojo](tts_dojo/TTS_dojo_guide.md) provides tools that automate this step.
- This model should be similar in tone and accent to the target voice, as well as being in the target language.
- It must also use the same sampling rate as your training data
- The file you need will have a name like `epoch=2164-step=135554.ckpt`
- Checkpoint files for piper's built in models can be found at [https://huggingface.co/datasets/piper-checkpoints/tree/main](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main)
- Here's a link to the lessac medium quality voice which I used in testing
https://huggingface.co/datasets/rhasspy/piper-checkpoints/blob/main/en/en_US/lessac/medium/epoch%3D2164-step%3D1355540.ckpt
- copy this checkpoint file into your `elvis_training` directory

## Step 8: Training!
### note: The [TTS Dojo](tts_dojo/TTS_dojo_guide.md) provides tools that automate this step.
1. change to `/path/to/piper/src/python` directory and ensure your venv is activated.
2. Run the following shell script (but change the paths for dataset_dir and resume_from_checkpoint first!)
```
python3 -m piper_train \
    --dataset-dir /path/to/elvis_training/ \
    --accelerator gpu \
    --devices 1 \
    --batch-size 4 \
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 30000 \
    --resume_from_checkpoint /path/to/epoch=2164-step=135554.ckpt \
    --checkpoint-epochs 1 \
    --precision 32
```
3.  You may need to adjust your batch size if your GPU runs out of memory.
4.  Training has started!  You will know it is working if the epoch number starts going up.
6.  You can monitor training progress with tensorboard. , ie:
    `tensorboard --logdir /path/to/elvis_training/lightning_logs`
7.  When tensorboard's graph for "loss_disc_all" levels off, you can abort the training process with CTRL-C in the terminal window where training is happening.

## Step 9 : Converting finetuned checkpoint file to a text-to-speech model
### note: The [TTS Dojo](tts_dojo/TTS_dojo_guide.md) provides tools that automate this step.
1. Create a new directory for your text to speech model eg `elvisTTS`
2. Locate your finetuned checkpoint file for this training session.  It will be found in `/path/to/elvis_training/lightning_logs/version_<N>/checkpoints/` 
3. This file can be converted into  `.onnx` format as follows:
```
python3 -m piper_train.export_onnx \
    /path/to/elvis_training/lightning_logs/version_<N>/checkpoints/<EPOCH____>.ckpt \
    /path/to/elvisTTS/elvis.onnx
```
4. Copy config.json from `elvis_training` to `elvisTTS`.   It needs to be renamed to match the `onnx` file, eg, `elvis.onnx.json`
```
cp /path/to/training_dir/config.json \
   /path/to/elvisTTS/elvis.onnx.json
```
   
## Step 10: Testing:
### note: The [TTS Dojo](tts_dojo/TTS_dojo_guide.md) provides tools that automate this step.
- `echo 'Thank you. Thank you very much!' | piper -m /path/to/elvisTTS/elvis.onnx --output_file testaudio.wav`
- Play the wav file either by double clicking it in your filesystem or with `aplay testaudio.wav`

















   
