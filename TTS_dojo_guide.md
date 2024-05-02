# TTS Dojo

The TTS Dojo automates the training workflow

# Things you will need to gather 
- a dataset for your target voice consisting of a collection of wav files and a metadata.csv file containing the transcripts.
- a checkpoint file of a partially trained text-to-speech model
- See [README.md](README.md) if you need instructions

### Prepare a new dojo
- run `python new_dojo.py --voice (YOURVOICENAME)` to create the directory structure to train your new voice.
- Your dojo will be created in  `<YOURVOICENAME>_dojo`

## Organizing files need for training.
- copy your target voice dataset's `wav` folder and `metadata.csv` file into the `target_voice_dataset` directory.
- copy your pretrained TTS `ckpt` file into the `pretrained_tts_checkpoint` directory.
- edit training parameters in `dojo_config.py` if you want to skip interactive installation.

## Do the training
- run `python train.py`
- 
  
  


