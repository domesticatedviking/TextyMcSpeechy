# How to use the PRETRAINED_CHECKPOINTS folder

- This folder provides a convenient way to download and organize pretrained checkpoint files that are used to speed up the training process.
- Checkpoint files have names like `epoch=2164-step=1355540.ckpt`, which doesn't include any information about the type of voice (M/F) or the quality level of the voice (low, medium, high).  For this reason we use a folder structure to keep these files organized.
- **IMPORTANT:** Your `.ckpt` files must be named using the `epoch=<xxxx>-step=<yyyyyyyyyy>.ckpt` pattern, otherwise training will fail.
- The files stored in the `PRETRAINED_CHECKPOINTS/default` folder allow your dojo's `run_training.sh ` to automatically choose a checkpoint whose voice type and quality level are appropriate for the settings of your tts dojo.
- You can make your own choices about which pretrained checkpoint files you want to store in these folders, but only one checkpoint file is allowed to be in each folder.
- `download_defaults.sh` is a script that makes getting pretrained checkpoints a bit easier, however since there are not pretrained checkpoints available for all quality levels and voice types in all languages, you will still need to pay attention to which checkpoints actually get downloaded.

## Important things to know: 
- If you are training a model from pretrained checkpoints, you **MUST** use a pretrained checkpoint of the **same quality** (low, medium, or high) of the settings you have chosen in your tts dojo.
- Beware that for many languages, pretrained checkpoint files may not be available in all voice types and quality levels, even if you use the supplied `.conf` files.
- Check the contents of `.conf` files in `PRETRAINED_CHECKPOINTS/languages/*.conf` to see which checkpoint files they will download.  You can also edit these files to use different links if you prefer.

## I can't find a pretrained checkpoint in the right language, quality level, or voice type, what are my options?
If you can't find an appropriate checkpoint for your language, you have several options:
1.  You can train your model from scratch, ie without using a pretrained checkpoint file (select this when running `run_training.sh` in your dojo).  This is much slower than training from a pretrained checkpoint and may require larger datasets for ideal results.
2.  You can [download a pretrained checkpoint file](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main) of the appropriate quality and voice type **from a different language** and copy it into the appropriate folder in `PRETRAINED_CHECKPOINTS/default`.  This is faster than training from scratch but slower than training from a matching checkpoint.
3.  If you successfully train a voice using either of the options above, the dojo where you trained that voice will save checkpoints in the `voice_checkpoints` folder.   If you copy one of those files to the appropriate subfolder in  `PRETRAINED_CHECKPOINTS/default`, you will be able to use that file to speed up training of future models.  (You can get a complete set of pretrained checkpoints for your language this way).
