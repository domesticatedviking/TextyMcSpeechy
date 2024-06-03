## TextyMcSpeechy Dataset Recorder

- `dataset_recorder.sh` is a script that greatly simplifies the process of recording a dataset for a text to speech model.
- Usually recording a dataset involves saving hundreds of sound files, and meticulously copying their filenames along with a transcript of the words spoken into a metadata.csv file.
- This tool takes any metadata.csv file as input, prompting the user to record each phrase one at a time, and then saves it under its specified filename.
- This is an ideal tool for recording a text-to-speech dataset to train a Piper model to speak in one's own voice.

