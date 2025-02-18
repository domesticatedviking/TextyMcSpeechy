# How to rename Piper voices to comply with the official docs 

1. Per the Piper docs, your voices must be renamed according to the following scheme: `<language>_<REGION>-<name>-<quality>`, eg: `en_US-bob-medium`
  - `<language>_<REGION>` is the IETF BCP 47 format language code (eg `en_US`)
  - `name` is the name of the person or character to whom the voice belongs (eg. `bob`)
  -  `quality` is the model quality. Valid values are `x_low`, `low`, `medium`, and `high`
  - rename both your `.onnx` and `.onnx.json` files, eg: `en_US-bob-medium.onnx`,`en_US-bob-medium.onnx.json` Make sure the names match EXACTLY.
  - If you don't name your model in this format, Home Assistant may not recognize it.
     
2. Update the `dataset` field in your `.onnx.json` file to reflect the new name of your model.  This is important if you want your model to show up properly in voice assistant entities created in Settings > Voice Assistants.
Custom piper models found online don't always follow the standards piper expects. The `quality` field is one I have often had to change.  It usually works fine if you set it to "Medium". I am still exploring what is expected by home assistant a bit here.
If your model name is `en_US-bob-medium`, your  `en_US-bob-medium.onnx.json` file should look something like this:
```
{
    "dataset": "en_US-bob-medium",
    "audio": {
        "sample_rate": 22050,
        "quality": "Medium"
    },
    "espeak": {
        "voice": "en-us"
    },
    "language": {
        "code": "en-us"
    },
    "inference": {
        "noise_scale": 0.667,
        "length_scale": 1,
        "noise_w": 0.8
    },
    # etc
```
