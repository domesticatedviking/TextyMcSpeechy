## TextyMcSpeechy Dataset Recorder

`dataset_recorder.sh` is a script that greatly simplifies the process of recording a dataset for a text to speech model.
- Usually recording a dataset involves saving hundreds of sound files, and meticulously copying their filenames along with a transcript of the words spoken into a metadata.csv file.
- This tool takes any metadata.csv file as input, prompting the user to record each phrase one at a time, and then saves it under its specified filename.
- This is an ideal tool for recording a text-to-speech dataset to train a Piper model to speak in one's own voice.

`remove_roomtone.sh` is a script that can batch remove background noise from your dataset. 
- You must supply a file eg `roomtone.wav` containing just the background noise in the environment where you recorded your dataset.
- If using `dataset_recorder.sh` to capture your dataset, you may wish to add the following line to the beginning of your `metadata.csv` file to prompt you to record roomtone:
```
roomtone|(CAPTURE 10-20 SECONDS OF SILENCE FOR NOISE REDUCTION PURPOSES)
```
