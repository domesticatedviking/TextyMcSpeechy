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

## Option A: convert a generic dataset into the target voice using an RVC model, then train TTS.
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


## Option B: train TTS using your own dataset (audio files in target voice and text transcript)
1. Install Piper
(skip steps 2,3,4,and,5)
6. Prepare the converted dataset for use with Piper
7. Get a checkpoint `ckpt` file for an existing text-to-speech model similar in tone/accent to the target voice.
8. Use Piper to fine-tune the existing text-to-speech model using the converted dataset.
9. Convert the fine-tuned `.ckpt` file to a `.onnx` file that can be used by Piper directly to generate speech from text.
10. Test the new text-to-speech model.










   
