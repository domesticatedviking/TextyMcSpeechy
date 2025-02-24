# How to rename Piper voices to comply with the official Piper specifications
### Note:  The TTS dojo now exports voices using this standard by default.

1. Per the Piper docs, your voices must be renamed according to the following scheme: `<language>_<REGION>-<name>-<quality>`, eg: `en_US-bob-medium`
  - `<language>_<REGION>` is the IETF BCP 47 format language code (eg `en_US`, `de`, `ru`)
  - `name` is the name of the person or character to whom the voice belongs (eg. `bob`)
  -  `quality` is the model quality. Valid values are `x_low`, `low`, `medium`, and `high`
  - rename both your `.onnx` and `.onnx.json` files, eg: `en_US-bob-medium.onnx`,`en_US-bob-medium.onnx.json` Make sure the names match EXACTLY.
  - If you don't name your model in this format **and** update the fields in your `.onnx.json` file, Home Assistant will not be able to use your voices. If you get errors when you use the `TRY VOICE` button in `Settings` > `Voice Assistants`, it is very likely you have a mistake in one of the fields of your `.onnx.json` file.     
2. Update your `.onnx.json` file by opening it in a text editor.   **All fields are case sensitive and must enclose strings in double quotes.**
   - `"dataset":`  must contain the filename of your model, **without its extension**, eg `"en_US-bob-medium"`.  
   - `"quality":`  must contain the quality code specified in the filename.  `"x_low"`, `"low"`, `"medium"`, or `"high"`.
   -  `"espeak": {"voice":""}` must contain the `espeak-ng` language identifier.  Please note that this is *NOT* the same language code used at the beginning of the filename. It may look very similar (compare `"en-us"` vs `"en_US"`), and for many languages the `espeak-ng` identifier is in fact identical to the IETF BCP 47 code, but they do not come from the same list.   A list of language identifiers to use for this field can be found [here](/tts_dojo/DATASETS/espeak_language_identifiers.txt).
   -  `"language": {"code":""}` must be set to the same language code used at the beginning of your filename.


If your model name is `en_US-bob-medium`, your  `en_US-bob-medium.onnx.json` file should look something like this.  Note that some models in the wild do not have a `dataset` or a `language` field.  You can add these yourself using this as a template.
```
{
    "dataset": "en_US-bob-medium",   
    "audio": {
        "sample_rate": 22050,
        "quality": "medium"
    },
    "espeak": {
        "voice": "en-us"
    },
    "language": {
        "code": "en_US"     
    },
    "inference": {
        "noise_scale": 0.667,
        "length_scale": 1,
        "noise_w": 0.8
    },
    # etc
```
- You may need to restart the Piper add-on, reload the Wyoming integration, restart your Piper docker container if running on GPU, and/or restart Home Assistant for your changes to show up.
