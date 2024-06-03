# TextyMcSpeechy

## A workflow with convenience scripts for making any voice into a Piper text-to-speech (TTS) model.
- Make a custom text-to-speech (TTS) model out of your own voice samples
- Make a custom TTS model out of any existing voice dataset
- Make a custom TTS model by converting a generic voice dataset into another voice using an RVC model.
- Rapidly train high quality TTS by using pretrained checkpoint files

## June 2 2024:  Feature update: Better management of datasets and pretrained checkpoints.
- Saving datasets and pretrained checkpoint files for future use has been a bit cumbersome up to this point.  This update fixes that.
- Voice datasets will be built in `tts_dojo/DATASETS` by a new dataset builder script.  This replaces the previous dataset sanitizer.
- Datasets are now automatically symlinked rather than copied to the dojo directory.
- Default options for pretrained checkpoint files are now organized in `tts_dojo/PRETRAINED_CHECKPOINTS`.
- You can store default checkpoints for traditionally male and female voice types for all three quality settings.
- A downloader script now populates the pretrained checkpoints directory.  This is currently set up with links for `en-us` only but will download checkpoints for other languages if links are changed in the script. I plan to rework this script to make it easier for other languages to be added.
- The `MY_FILES` folder and `add_my_files.sh` have been removed .    `start_training.sh` now handles everything.


## May 27 2024:  New tool - Dataset recorder
- This is probably the fastest possible way to record a dataset, and is ideal for making a clone of one's own voice.
- `dataset_recorder.sh` takes any metadata.csv file as input and interactively records voice samples for every phrase it references under the proper file name.
- a sample `metadata.csv` file is included.   I'm still experimenting to see what kinds of phrases will result in the best voice clones.

## MAJOR FEATURE UPDATE May 24 2024 
- The latest commit includes a completely overhauled TTS dojo, with the ability to generate and listen to tts voices while training
- Output still needs some polishing but otherwise everything seems to work quite well.
- My focus over the next few weeks will be less on the development of this project and more on what I can make using this project.




## Shortcut to the TextyMcSpeechy TTS dojo:
If you:
- have already installed Piper
- have a folder full of 16000Hz or 22050Hz `wav` files in your target voice and a `metadata.csv` with the transcriptions
- have a `.ckpt` file for a piper TTS voice compatible with the sampling rate of your dataset
  
#### [proceed directly to the TTS Dojo documentation](tts_dojo/TTS_dojo_guide.md).

## Tools required
1. Piper: [https://github.com/rhasspy/piper](https://github.com/rhasspy/piper)
2. A checkpoint `ckpt` file of any existing pretrained text-to-speech model.  (available [here](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main))
3. A voice dataset with audio files and text transcriptions.  These can either be samples of the target voice, or a generic dataset that will be converted into another voice with Applio.
4. Applio: https://github.com/IAHispano/Applio Used to batch-convert a generic voice dataset into the target voice using an RVC model.

## Recommended hardware and notes about performance
1. A PC running Linux which has a NVIDIA GPU is highly recommended / required for training.
2. Once TTS models are trained, they will run on much less powerful hardware, but Piper uses a neural network to generate speech.  This is a computationally expensive process which benefits from fast hardware.
3. A Raspberry Pi 5 should be considered the absolute minimum for realtime applications like smart speakers or voice assistants.  
4. My Raspberry Pi 5 (8GB) based offline smart speaker project had a delay of about 8 seconds between saying a voice command (transcribed locally on the pi with faster-whisper) and a spoken response beginning from a low-quality piper-TTS voice. At least 3/4 of the delay was waiting for Piper to finish generating speech.  If real-time responses with minimal lag are needed, I would strongly recommend planning to run Piper on something faster than a Pi 5. If you use use low-quality Piper models, keep spoken phrases short, or cache commonly used phrases as pre-rendered audio files, a Pi 5 (or even a Pi 4) may be adequate for your needs.  Personally I'll be waiting for the Pi 6 or Pi 7 before I try to do this again.
5. Performance improves dramatically when rendering speech on more powerful hardware. When running both STT transcription and Piper TTS on the CPU of my desktop computer (Core i7-13700), the delay between command and spoken response fell to less than 3 seconds, which was comparable to what I get with Google Assistant on my Nest Mini.  Whisperlive and Piper both include HTTP servers, which makes it easy to move STT and TTS processes to a network computer or self-managed cloud server.  I'm planning to use this approach in my smart speaker project, which will now be based on a Raspberry Pi Zero 2W.


# Overview of the process
## Note 1: regardless of which workflow you use to get your dataset, the [TTS Dojo](tts_dojo/TTS_dojo_guide.md) will make it significantly easier to train and package your model.
## Note 2: need an easy-to-use English dataset?  Be sure to check out the scripts [here](VCTK_dataset_tools/using_vctk_dataset.md).

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


### Option B: train TTS using your own dataset (audio files in target voice and text transcript)
1. Install Piper 

 (skip steps 2,3,4,and,5)
 
6. Prepare the converted dataset for use with Piper
7. Get a checkpoint `ckpt` file for an existing text-to-speech model similar in tone/accent to the target voice.
8. Use Piper to fine-tune the existing text-to-speech model using the converted dataset.
9. Convert the fine-tuned `.ckpt` file to a `.onnx` file that can be used by Piper directly to generate speech from text.
10. Test the new text-to-speech model.


# Guide

## Step 1: Installing Piper
### I strongly recommend using `install_piper.sh` to install Piper.  This will allow you to use the TTS dojo without further configuration.

1. `sudo apt-get install python3.dev`
2. `git clone https://github.com/rhasspy/piper.git`  
3. `cd piper/src/python`  (You will have an easier time if you put your venv in this directory)
4. `python3.10 -m venv .venv`  note - Torch needs python 3.10 and won't work on 3.11 without extra steps. 
5. `source ./.venv/bin/activate`
6. `pip install pip wheel setuptools -U`  
7. `pip install piper-tts`
8. `pip install build` 
9. `python -m build` 
10. `pip install -e .`
11. `pip3 install -r requirements.txt`
12. `bash ./build_monotonic_align.sh`
13. `sudo apt-get install espeak-ng`
14. `pip install torchmetrics==0.11.4`  (this is a downgrade to avoid an error)



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
- see [VCTK_dataset_tools](VCTK_dataset_tools/using_vctk_dataset.md) for some helpful scripts for generating metatata.csv if your model uses individual text files

## Step 5: Convert dataset into the target voice
- Convert all of the audio files in the dataset into the target voice using Applio.
- Batch conversion of a generic dataset into another voice can be done on the "Inference" tab.
- Select the Batch tab, choose a voice model, specify the location of your input and output folders, then click "Convert"

## Step 6: Preparing your dataset for use with Piper
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

## Step 7: Get an existing text to speech model to fine-tune
- This model should be similar in tone and accent to the target voice, as well as being in the target language.
- It must also use the same sampling rate as your training data
- The file you need will have a name like `epoch=2164-step=135554.ckpt`
- Checkpoint files for piper's built in models can be found at [https://huggingface.co/datasets/piper-checkpoints/tree/main](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main)
- Here's a link to the lessac medium quality voice which I used in testing
https://huggingface.co/datasets/rhasspy/piper-checkpoints/blob/main/en/en_US/lessac/medium/epoch%3D2164-step%3D1355540.ckpt
- copy this checkpoint file into your `elvis_training` directory

## Step 8: Training!
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
- `echo 'Thank you. Thank you very much!' | piper -m /path/to/elvisTTS/elvis.onnx --output_file testaudio.wav`
- Play the wav file either by double clicking it in your filesystem or with `aplay testaudio.wav`

















   
