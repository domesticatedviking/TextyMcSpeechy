# A quick start guide for using TextyMcSpeechy once you have a dataset.

1. clone the repository `git clone https://github.com/domesticatedviking/TextyMcSpeechy.git`
2. from the repository directory, run `./install_piper.sh`
3. run `tts_dojo/PRETRAINED_CHECKPOINTS/download_defaults.sh` to download a set of pretrained checkpoint files. (currently `en-us` is the only language option set up)
4. You can use `PRETRAINED_CHECKPOINTS/languages/en-us.conf` as a template for making `.conf` files to download piper checkpoints for other languages.  Pull requests are welcome.
5. Copy your audio files and `metadata.csv` file to a new directory inside of `tts_dojo/DATASETS`.  Keep backups of your original files!  
6. from `tts_dojo/DATASETS`, run `./create_dataset.sh <your_dataset_dir>` to set up your dataset.  This will sort your files by file format and sampling rate, and automatically create 22050hz and 16000hz `.wav` versions of your files if they do not exist. It will also ensure that files mentioned in `metadata.csv` are present.
7. run `tts_dojo/newdojo.sh <voice_name>` to create a dojo for the voice you are about to build.
8. inside of `<voice_name>_dojo`, run `./run_training.sh`
9. You will be prompted to choose a dataset, the dataset will be pre-processed, and training will begin.
