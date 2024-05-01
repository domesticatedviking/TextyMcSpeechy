# TextyMcSpeechy
Convenience scripts and directory structure for making text-to-speech models in any voice for rhasspy/piper
(Currently under construction)

- a NVIDIA GPU is strongly recommended for training

## Tools used
1. Piper: `https://github.com/rhasspy/piper`
3. A checkpoint `ckpt` file of any existing pretrained text-to-speech model.  (available [here](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main/en/en_US))
4. A voice dataset with audio files and text transcriptions.  These can either be samples of the target voice, or a generic dataset that will be converted into another voice with Applio.
5. Applio: https://github.com/IAHispano/Applio (optional) Used to batch-convert a generic voice into the target voice using an RVC model.
6. A NVIDIA GPU is highly recommended for training.

# Overview of the process

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


# The fast way
1. Install Piper (see step 1 of "The Long Way" below)
2. (optional) Install Applio (see steps 2 and 3 of "The Long Way" below)
3. Read the rest of "The Long Way" to understand what files you need.
4. Use the *TextyMcSpeechy dojo* to organize your files and train your model


# The long way

## Step 1: Installing Piper
*important* - use python 3.10 as torch does not support python 3.11
1. `sudo apt-get install python3.dev`
2. `git clone https://github.com/rhasspy/piper.git`
3. `cd piper/src/python`
4. `python3.10 -m venv .venv`  note - Torch needs python 3.10 and won't work on 3.11
5. `source ./.venv/bin/activate`
6. `pip install pip wheel setuptools -U`  (the -U is not in official docs?)
7. `pip install -e .`
7. `pip3 install -r requirements.txt`
8. `bash ./build_monotonic_align.sh`
9. `sudo apt-get install espeak-ng`

If torchmetrics causes an error when training, downgrade to 0.11.4 `pip install torchmetrics==0.11.4`

## Step 2: Installing Applio
- Follow instructions here `https://github.com/IAHispano/Applio`

## Step 3: Finding the voice you want in Applio
- More to come later
- (It has a nice gui - it isn't very hard to figure out)

## Step 4: Getting a training dataset
1. A dataset is a collection of audio clips with matching text transcriptions.  There are many options available in the public domain, or you can record and transcribe your own voice.  A repo with many public domain datasets can be found here:  https://github.com/jim-schwoebel/voice_datasets
2. For voice cloning, it is best if the person speaking in the dataset has a voice similar in tone and accent to the target voice.  Keep in mind that some datasets include audio from multiple speakers.
3. Piper requires transcription data to be gathered into a single `metadata.csv` file, with one line per wav file in the following format:
   - `FILENAME` | `SPEAKER ID` | `transcript`

Here's an example of what a metadata.csv file should look like for a single speaker dataset
```
p316_001_mic1_output|0|Please call Stella.
p316_002_mic1_output|0|Ask her to bring these things with her from the store.
p316_003_mic1_output|0|Six spoons of fresh snow peas, five thick slabs of blue cheese
```
- see Appendix below for some helpful scripts for generating metatata.csv if your model uses individual text files

## Step 5: Convert dataset into the target voice
1. Convert all of the audio files in the dataset into the target voice using Applio.  There's a very useful batch-conversion option here.

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
- Checkpoint files for piper's built in models can be found at https://huggingface.co/datasets/piper-checkpoints/
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

# Appendix: How I used the VCTK dataset for training
- the VCTK dataset can be found here: https://datashare.ed.ac.uk/handle/10283/3443
- Since it is a multi-speaker dataset, it can't be used directly.  However, since it contains a wide variety of voices speaking the same sentences, it can be useful for finding a voice that is a close match for the target voice
- `speaker-info.txt` contains details about the gender and regional dialect of each speaker in the corpus.
```
ID  AGE  GENDER  ACCENTS  REGION COMMENTS 
p225  23  F    English    Southern  England
p226  22  M    English    Surrey
p227  38  M    English    Cumbria
p228  22  F    English    Southern  England
p229  23  F    English    Southern  England
```
- Voice samples are found in `wav48_silence_trimmed` directory, and are grouped in folders with each speaker's ID eg. `p225`
- Transcripts for each utterance are found it the "txt" directory, also grouped in folders with each speaker's ID.
- After I knew which voice I wanted, I did as follows:
```
mkdir singlevoice
cp wav48_silence_trimmed/p225/* singlevoice/wav
cp txt/p225/* singlevoice/txt
```
- Each audio sample in the VCTK dataset was recorded with 2 different mics.  I removed all the files recorded with the second mic to make the next step easier

```
rm singlevoice/*mic2
```
- Finally, I used the following script to create a metadata.csv file from the file names and individual text files:

```
ls txt/*/*.txt | while read TXT ; do \
      BASE=`basename $TXT .txt` \
      LINE=`cat $TXT` ; \
      SPKR=`echo $BASE | awk -F_ '{print $1}'` \
      if [ $SPKR == p225 ] ; then \
         LINE=${LINE:1:-1} ; ## remove initial and final " in p225 data \
      fi \
      echo "${BASE}_mic1_output|0|$LINE" \
done >> metadata.csv
```











   
