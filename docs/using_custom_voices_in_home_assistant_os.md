## How to install and use a custom voice model on Home Assistant OS
I put together this guide because I couldn't find an adequate explanation of how to do this anywhere else.  Please read carefully as there are currently some issues arising from the way Piper is implemented in Home Assistant that make this process more confusing than it should be.

## Install Piper add-on and Wyoming protocol integration
 1. Install the Piper Add-on (Settings > Addons > click ADD-ON STORE button > search for Piper.)
 2. Install the Wyoming protocol integration (Settings > Devices & Services > Integrations > Click ADD INTEGRATION BUTTON > Wyoming Protocol).
 3. When prompted by Wyoming Protocol for host and port, you can use `core-piper` for `host` and `10200` for `port`
    - `core-piper` is the hostname provided by the piper add-on's docker container. You can also use the ip address of the machine running the docker container. 
    - `10200` is the default port for Piper. Change it as needed.  

## Prepare your custom voice models for upload
1. Important: Per the Piper docs, your voices must be renamed according to the following scheme: `<language>_<REGION>-<name>-<quality>`, eg: `en_US-bob-medium`
  - `<language>_<REGION>` is the IETF BCP 47 format language code (eg `en_US`)
  - `name` is the name of the person or character to whom the voice belongs
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
## Upload your renamed `.onnx` and `.onnx.json` files to /share/piper  
- This is a bit challenging on Home Assistant OS since you don't have permissions to upload to this folder via the webui.
- There are a variety of ways of accomplishing this which are beyond the scope of this guide.
- If you don't find a `piper` directory inside `/share`, create it yourself.
- I did this by installing the FTP Add-on (Settings > Add-ons > click ADD-ON STORE button > search for FTP)
- After setting up credentials in the FTP add-on and ensuring it was up and running, I used [Filezilla](https://filezilla-project.org) (FTP client software) on my PC to connect to the server and upload my model files to `/share/piper`.

## How do I use my custom models?
Once your `.onnx` and `.onnx.json` files are in the `/share/piper` folder, restart the Piper add-on and reload the Wyoming Protocol integration, otherwise they won't know about your models.
- If you have done everything correctly so far, your voice will technically be ready to use, but there are some implementation issues you need to know about.
- *Important*: Due to the way the Piper add-on currently gets its voice lists, if you go to `Settings > Add-ons > Piper > Configuration` and look for your custom voice in the dropdown window, you won't find your custom voices there. I have opened an [issue](https://github.com/home-assistant/addons/issues/3914) for this on github. 
- The only place you are currently able to see your custom voice in the webui is in Settings > Voice Assistants, after creating or modifying a voice assistant entity using Piper as the text to speech engine.
- There is a "Try Voice" button you can use to verify that your custom voice is working properly.  I recommend doing this  before proceeding further.
- If your custom model shows up with the wrong name, you probably need to change some fields in your `.onnx.json` file and restart Piper/Wyoming protocol.

## How do I use my custom voices in my own scripts?

Once you have a model that you know works, here's how you can make use of it in your own scripts just as easily as any other TTS service.

1. Create a script for your custom voice which accepts a template value as an input. The script below is called `say_as_bob`  (note that you need to use your own `media_player_entity_id` and `voice` ).  
```
action: tts.speak
metadata: {}
data:
  cache: true
  message: "{{ message }}"
  media_player_entity_id: media_player.myspeakername
  options:
    voice: en_US-bob-medium
target:
  entity_id: tts.piper

```

2. To call the `say_as_bob` service script above to make Piper say things in Bob's voice , use the format of the `introduce_bob` example below (this `yaml` also can be used  from developer tools > actions)

```
action: script.say_as_bob
data_template:
  message: "Pleased to meet you, I'm bob"

```
