# How to use the PRETRAINED_CHECKPOINTS folder

- This folder provides a convenient way to download and organize pretrained checkpoint files that are used to speed up the training process.
- Checkpoint files have names like `epoch=2164-step=1355540.ckpt`, which doesn't include any information about the type of voice (M/F) or the quality level of the voice (low, medium, high).  For this reason we use a folder structure to keep these files organized.
- **IMPORTANT:** Your `.ckpt` files must be named using the `epoch=<xxxx>-step=<yyyyyyyyyy>.ckpt` pattern, otherwise training will fail.
- The files stored in the `PRETRAINED_CHECKPOINTS/default` folder allow your dojo's `run_training.sh ` to automatically choose a checkpoint whose voice type and quality level are appropriate for the settings of your tts dojo.
- You can make your own choices about which pretrained checkpoint files you want to store in these folders, but only one checkpoint file is allowed to be in each folder.
- `download_defaults.sh` is a script that makes getting pretrained checkpoints a bit easier, however since there are not pretrained checkpoints available for all quality levels and voice types in all languages, you will still need to pay attention to which checkpoints actually get downloaded.
- For your convenience, a set of pretrained checkpoints that can be used to train `medium` and `high` quality voices in any language can be downloaded by running `download_defaults.sh generic`. These checkpoints may not provide the best possible results in every case, but they should make it easier for new users to get started.

## Important things to know: 
- There are very few compatible "low" quality pretrained checkpoints on huggingface, so you if you need a low quality model you will probably need to train it from scratch.
- If you are training a model from pretrained checkpoints, you **MUST** use a pretrained checkpoint of the **same quality** (low, medium, or high) of the settings you have chosen in your tts dojo.
- Beware that for many languages, pretrained checkpoint files may not be available in all voice types and quality levels, even if you use the supplied `.conf` files.
- Check the contents of `.conf` files in `PRETRAINED_CHECKPOINTS/languages/*.conf` to see which checkpoint files they will download.  You can also edit these files to use different links if you prefer.
- Note that currently, `download_defaults.sh` infers the quality level and voice type from the huggingface URL.   Checkpoint links from other sites are not presently supported by `download_defaults.sh`, but can still be used if you add them manually to `PRETRAINED_CHECKPOINTS/default` subfolders.

## I can't find a pretrained checkpoint in the right language, quality level, or voice type, what are my options?
If you can't find an appropriate checkpoint for your language, you have several options:
1.  You can try training using the "generic" checkpoints (run `download_defaults.sh generic`).  Note that only medium and high quality voices can be trained this way at this time due to a lack of low quality pretrained checkpoints on huggingface.
2.  You can train your model from scratch, ie without using a pretrained checkpoint file (select this when running `run_training.sh` in your dojo).  This is much slower than training from a pretrained checkpoint and may require larger datasets for ideal results.
3.  You can [download a pretrained checkpoint file](https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main) **of the appropriate quality** and voice type **from a different language** and copy it into the appropriate subfolder of `PRETRAINED_CHECKPOINTS/default`.  This is faster than training from scratch but slower than training from a matching checkpoint.  Note that you may need to rename the file to match the required `epoch=1234-step=123456789.ckpt` filename format. If the checkpoint you downloaded has only one number in the filename, use if for the epoch number.  If either number isn't supplied, use the example or make one up - any number will work.
4.  If you successfully train a voice using either of the options above, the dojo where you trained that voice will save checkpoints in the `voice_checkpoints` folder.   If you copy one of those files to the appropriate subfolder in  `PRETRAINED_CHECKPOINTS/default`, you will be able to use that file to speed up training of future models.  (Over time you will be able to build a complete set of pretrained checkpoints for your language by doing this).
