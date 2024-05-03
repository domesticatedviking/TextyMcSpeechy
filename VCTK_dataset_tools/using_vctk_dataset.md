# Getting a usable single speaker dataset from the VCTK dataset
## Quick instructions
1. `download_vctk_dataset.sh`  Download and unzip dataset.  Note that it is quite large (over 11GB)
2. `single_voice_from_VCTK_dataset.sh pNNN` Repackages a single speaker's voice from this dataset and generates `metadata.csv`
3. `downsample_and_convert --dataset_dir pNNN_original_speaker --sampling_rate 16000`  Batch converts flac files to wav and downsamples them.  Original files are backed up in `flac` directory prior to conversion.



## Background on using VCTK dataset for training
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
