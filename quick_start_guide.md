# A quick start guide for using TextyMcSpeechy 

## What is a training dataset?
- A training dataset consists of audio recordings of speech, along with a `metadata.csv` file that contains a text transcript of the words spoken in each recording.
- The `metadata.csv` file is a plain text file that should look something like this
```
roomtone|Please record twenty seconds of silence to remove roomtone
file0001|The rain in Spain falls mainly on the plain.
file0002|Ask her to bring these things with her from the store.
file0003|Six thick slabs of mozzerella cheese.
```
- Each line in the dataset begins with the name of an audio file. Do not include the file extension (eg `.wav`). 
- After the `|` character, there is a text transcription of the exact words spoken in the audio file in the first column.
- It doesn't matter what you name your files as long as the transcriptions match the words recorded in the filename in the first column.
- The more phrases you use the more accurate your voice will be, but it will also take much longer to train.
- A sweet spot for dataset size is from 50-200 phrases, with recordings ranging in length from ~1-15 seconds each.

## Where do I get a dataset?
To make a custom text to speech voice requires a custom dataset.   Building a custom dataset requires a bit of work.
- The fastest way to get a dataset is to use the scripts provided in the `dataset_recorder` directory to record a dataset using your own voice. I highly recommend everyone tries this option at least once.
- You can also create a dataset from any collection of short audio clips that you manually transcribe into a `metadata.csv` file.
- It is also possible to download a [public domain training dataset](https://github.com/jim-schwoebel/voice_datasets) and batch-convert the provided audio files to sound like a different voice with an existing RVC voice changer model using [Applio](https://github.com/IAHispano/Applio).  This is quicker because you don't have to transcribe the dataset - you use the `metadata.csv` file that came with the original dataset for training.


## I have my dataset, how do I use it to train my text to speech model?

1. clone the TextyMcspeechy repository if you haven't already done so. `git clone https://github.com/domesticatedviking/TextyMcSpeechy.git`
2. from the repository directory, run `./setup.sh` to get the `textymcspeechy-piper` docker image you will need to train voices.
3. `cd tts_dojo/PRETRAINED_CHECKPOINTS`
4. To download a complete set of pretrained checkpoint files, from `tts_dojo/PRETRAINED_CHECKPOINTS` run `download_defaults.sh en-us` (currently `en-us` is the only preconfigured language option)
5. You can use `PRETRAINED_CHECKPOINTS/languages/en-us.conf` as a template for making `.conf` files to download piper checkpoints for other languages.  Pull requests are welcome.
6. Copy your audio files and `metadata.csv` file to a new directory inside of `tts_dojo/DATASETS`.  Keep backups of your original files!  
7. from `tts_dojo/DATASETS`, run `./create_dataset.sh <your_dataset_dir>` to set up your dataset.  This will sort your files by file format and sampling rate, and automatically create 22050hz and 16000hz `.wav` versions of your files if they do not exist. It will also ensure that files mentioned in `metadata.csv` are present.
8. run `tts_dojo/newdojo.sh <voice_name>` to create a dojo for the voice you are about to build.
9. inside of `<voice_name>_dojo`, run `./run_training.sh`
10. You will be prompted to choose a dataset, the dataset will be pre-processed, and training will begin.
11. TextyMcspeechy works by starting a Piper training session, periodically grabbing the `.ckpt` files that Piper creates, and converting them into usable Piper voice models, which are stored in `tts_dojo/yourvoice_dojo/tts_voices`. The amount of time it takes to train a voice is highly dependent the size of your dataset, and it is not unusual for it to take 20 minutes or more for the first voice model to be generated.    Because each individual checkpoint file is over 800MB, TextyMcSpeechy doesn't save all of the checkpoints that Piper generates.   You can adjust how often checkpoints are saved or manually save the current checkpoint at any point in the training process from the Checkpoint Grabber window.  Whenever the checkpoint grabber saves a checkpoint, it also immediately converts it into a usable Piper voice and saves it in `tts_dojo/yourvoice_dojo/tts_voices`.
