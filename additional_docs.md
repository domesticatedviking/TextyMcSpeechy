## How to modify pronunciation 
- Thanks to Thorsten Mueller for this helpful [tutorial](https://www.youtube.com/watch?v=493xbPIQBSU) which gives tips on how to add custom pronunciation rules to `espeak-ng`, which `piper` relies on.
- If you notice that words aren't being pronounced correctly even when they are recorded correctly  in your audio dataset, it is likely because the phonemes supplied by `espeak-ng` are incorrect.
### Basic steps
- confirm that espeak-ng is installed: `dpkg -l|grep -i espeak`
- Clone the espeak-ng git repo to get the files you will need to modify:  `git clone https://github.com/espeak-ng/espeak-ng.git`
- Open the directory containing the dictionary source files `cd espeak-ng/dictsource`
- create a new custom pronunciation file named `en_extra`  (if using another language, substitute the language code for `en`)
- add the modified pronunciation rules to `en_extra` and save the file.
- Each line in `en_extra` begins with the text to be pronounced, followed by the pronunciation as represented in [Kirschenbaum](https://en.wikipedia.org/wiki/Kirshenbaum) format (Also known as ASCII-IPA or erkIPA format)
- If anyone has a good tool that can convert phonemes from unicode IPA directly to Kirschenbaum format, I would love to know about it.

```
#en_extra file format example
Noella  no'El:V O
```

- compile the pronunciation rules to make them active `sudo espeak-ng --compile=en`
- to test the new pronunciation:  `espeak-ng "your text here" --ipa`

## Using Piper voices on Android devices
- Note: this section is a work in progress

There is a project called [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) that can be used to package piper voice models for use with android devices.
The docs describing the steps of the conversion process are [here](https://k2-fsa.github.io/sherpa/onnx/tts/piper.html).
- Copy the `.onnx` and `.onnx.json` files for the Piper voice you wish to convert for use with `sherpa-onnx` into a new folder.
- make virtual environment  `python3 -m venv .venv`                    
- activate venv  `source .venv/bin/activate`                
- install dependencies `pip install onnx onnxruntime sherpa-onnx`
- Save the following script as `sherpaconvert.py` (based on the example from the docs, but with some fixes and improvements)
```
#!/usr/bin/env python3
# sherpaconvert.py 

import json
import os
import sys
from typing import Any, Dict

import onnx


def add_meta_data(filename: str, meta_data: Dict[str, Any]):
    """Add meta data to an ONNX model. It is changed in-place.

    Args:
      filename:
        Filename of the ONNX model to be changed.
      meta_data:
        Key-value pairs.
    """
    try:
        model = onnx.load(filename)
    except Exception as e:
        print(f"Error loading the ONNX model: {e}")
        sys.exit(1)

    for key, value in meta_data.items():
        meta = model.metadata_props.add()
        meta.key = key
        meta.value = str(value)

    onnx.save(model, filename)
    print(f"Meta data added to model: {filename}")


def load_config(model: str):
    """Load configuration from a JSON file named after the model.

    Args:
      model:
        The base name of the model file, used to load the corresponding .json configuration.

    Returns:
      config (dict): The parsed configuration data.
    """
    json_filename = f"{model}.json"
    if not os.path.exists(json_filename):
        print(f"Error: Configuration file {json_filename} does not exist.")
        sys.exit(1)

    with open(json_filename, "r") as file:
        config = json.load(file)
    return config


def generate_tokens(config: Dict):
    """Generate tokens file from phoneme id map in the config.

    Args:
      config: The configuration data containing phoneme id map.
    """
    id_map = config["phoneme_id_map"]
    try:
        with open("tokens.txt", "w", encoding="utf-8") as f:
            for s, i in id_map.items():
                f.write(f"{s} {i[0]}\n")
        print("Generated tokens.txt")
    except Exception as e:
        print(f"Error generating tokens.txt: {e}")
        sys.exit(1)


def main():
    """Main function to process the ONNX model and add metadata."""
    if len(sys.argv) != 2:
        print("Usage: python script_name.py <onnx_model_file>")
        sys.exit(1)

    filename = sys.argv[1]

    if not os.path.exists(filename):
        print(f"Error: The specified ONNX model file {filename} does not exist.")
        sys.exit(1)

    try:
        config = load_config(filename)
    except Exception as e:
        print(f"Error loading config: {e}")
        sys.exit(1)

    print("Generating tokens...")
    generate_tokens(config)

    print("Adding model metadata...")
    meta_data = {
        "model_type": "vits",
        "comment": "piper",  # must be piper for models from piper
        "language": config["language"]["code"],
        "voice": config["espeak"]["voice"],  # e.g., en-us
        "has_espeak": 1,
        "n_speakers": 1,
        "sample_rate": config["audio"]["sample_rate"],
    }
    print(meta_data)
    add_meta_data(filename, meta_data)


if __name__ == "__main__":
    main()
```

- Run the script.  This will create a `tokens.txt` file:
  `python sherpaconvert.py <yourmodelname>.onnx`

- Note:  `sherpa-onnx` voices consist of a `.onnx` file and `tokens.txt`.  Your `.onnx.json` file is no longer needed.
- Your piper model is now ready to use with `sherpa-onnx`. To use it with your android device it will first need to be packaged as a `.apk` file.  Once I figure that process out I will document it as well.
