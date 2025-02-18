# TextyMcSpeechy Dataset Recorder
![image](https://github.com/user-attachments/assets/8f68fa74-c36a-4105-af9b-1ab05f3e90b6)


`dataset_recorder.sh` is a script that greatly simplifies the process of recording a dataset for a text to speech model.
- Usually recording a dataset involves saving hundreds of sound files, and meticulously copying their filenames along with a transcript of the words spoken into a metadata.csv file.
- This tool takes any metadata.csv file as input, prompting the user to record each phrase one at a time, and then saves it under its specified filename.  In the example metadata.csv below, files will be saved to `1.wav`, `2.wav`, `3.wav`, etc.
- The provided `metadata.csv` file is AI generated.  You may get better voice models if you use a `metadata.csv` file from an academic public domain dataset.
- I like to inclde proper names and phrases I will be using in my application in my `metadata.csv` file.  While having them present in the dataset doesn't guarantee that training will produce a model that will pronounce them properly, it will make them sound very natural once appropriate [pronunciation rules](docs/altering_pronunciation.md) are set up. 

![image](https://github.com/user-attachments/assets/8432d26d-6612-4fd6-8a44-ff8831c12867)

- To begin recording a dataset, run:
```
./dataset_recorder.sh metadata.csv
```

![image](https://github.com/user-attachments/assets/2490a3a2-5b84-405b-8433-a6388a40af8a)

- This is an ideal tool for recording a text-to-speech dataset to train a Piper model to speak in one's own voice.

## Removing background noise from your dataset recordings
`remove_roomtone.sh` is a script that can batch remove background noise from your dataset using `sox`. 
- You must supply a file eg `roomtone.wav` containing just the background noise in the environment where you recorded your dataset.
- If using `dataset_recorder.sh` to capture your dataset, you may wish to add the following line to the beginning of your `metadata.csv` file to prompt you to record roomtone.  The file will be called `roomtone.wav`:
```
roomtone|(CAPTURE 10-20 SECONDS OF SILENCE FOR NOISE REDUCTION PURPOSES)
```
- To run `remove_roomtone.sh`:
```
Usage:
  ./remove_roomtone.sh <input_directory> <output_directory> [--roomtonepath <room_tone_wavfile>]
Arguments:
  input_directory   Directory containing your dataset's WAV files
  output_directory  Directory to save WAV files with background noise removed
  --roomtonepath    Path to a WAV recording of the background noise in the room where the dataset was recorded.
                    If not provided, the script checks ./roomtone.wav

./remove_roomtone.wav original_wavs noise_removed_wavs --roomtonepath /path/to/roomtone.wav
```
- I would recommend you keep your original recordings along with your roomtone file until you are satisfied with the results 
- **Important** - when packaging your dataset, make sure that `roomtone.wav` is **not** saved in the `DATASETS/<voicename>` folder.
- You will see warnings if a reference to `roomtone` is present in the `metadata.csv` file in the `DATASETS/<voicename>` directory when you preprocess your model.  These warnings will not interfere with training, but you can remove the `roomtone` line from `metadata.csv` to stop them from appearing.  Take care not to leave any blank lines in `metadata.csv` as Piper's preprocessing will fail if they are present.
