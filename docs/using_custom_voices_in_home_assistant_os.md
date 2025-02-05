## How to install and use a custom Piper voice model in Home Assistant OS
I put together this guide because I couldn't find an adequate explanation of how to do this anywhere else.  Please read carefully as there are currently some issues arising from the way Piper is implemented in Home Assistant that make this process more confusing than it should be.

## Install Piper add-on and Wyoming protocol integration
 1. Install the Piper Add-on (Settings > Addons > click ADD-ON STORE button > search for Piper.)
 2. Install the Wyoming protocol integration (Settings > Devices & Services > Integrations > Click ADD INTEGRATION BUTTON > search for Wyoming Protocol).
 3. When prompted by Wyoming Protocol for host and port, you can use `core-piper` for `host` and `10200` for `port`
    - `core-piper` is the hostname provided by the piper add-on's docker container. You can also use the ip address of the machine running the docker container. 
    - `10200` is the default port for Piper. Change it as needed.  

## Prepare your custom voice models for upload
1. Important: Per the Piper docs, your voices must be renamed according to the following scheme: `<language>_<REGION>-<name>-<quality>`, eg: `en_US-bob-medium`
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
## Upload your renamed `.onnx` and `.onnx.json` files to /share/piper  
- This is a bit challenging on Home Assistant OS since you don't have permissions to upload to this folder via the webui.
- There are a variety of ways of accomplishing this which are beyond the scope of this guide.
- If you don't find a `piper` directory inside `/share`, create it yourself.
- I did this by installing the FTP Add-on (Settings > Add-ons > click ADD-ON STORE button > search for FTP)
- After setting up credentials in the FTP add-on and ensuring it was up and running, I used [Filezilla](https://filezilla-project.org) (FTP client software) on my PC to connect to the server and upload my model files to `/share/piper`.

## How do I use my custom models?
Once your `.onnx` and `.onnx.json` files are in the `/share/piper` folder, restart the Piper add-on and reload the Wyoming Protocol integration, otherwise they won't know about your models.
- If you have done everything correctly so far, your voice will technically be ready to use, but there are some implementation issues you need to know about.
- *Important*: Due to the way the Piper add-on currently gets its voice lists, if you go to `Settings > Add-ons > Piper > Configuration` and look for your custom voice in the dropdown menu, you won't find your custom voices there. I have opened an [issue](https://github.com/home-assistant/addons/issues/3914) for this on github. 
- The only place you are currently able to see your custom voice in the webui is in Settings > Voice Assistants, after creating or modifying a voice assistant entity using Piper as the text to speech engine.
- There is a "Try Voice" button you can use to verify that your custom voice is working properly.  I recommend doing this  before proceeding further.
- If your custom model shows up with the wrong name, you probably need to change some fields in your `.onnx.json` file and restart Piper/Wyoming protocol.

## How do I use my custom voices in my own scripts?

Once you have a model that you know works, here's how you can make use of it in your own scripts just as easily as any other TTS service.

1. Create a script for your custom voice which accepts a template value as an input. The script below is called `say_as_bob`  (note that you need to use your own `media_player_entity_id` and `voice` ).  If you need output to go to multiple speakers, you can use a comma separated list (eg:  `media_player_entity_id: media_player.speaker1, media_player.speaker2`)
```
# "say_as_bob" tts service script  <-- (don't include this line in your script!)

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

2. To call the `say_as_bob` service script above to make Piper say things in Bob's voice, use the format of the `introduce_bob` script example below (this `yaml`  also can be used  from Developer Tools > Actions for test purposes)

```
# "introduce_bob" example usage script  <-- (don't include this line in your script!)

action: script.say_as_bob
data_template:
  message: "Pleased to meet you, I'm bob"

```

## A simple TTS voice tester GUI for Home Assistant lovelace dashboards

1. Create a dropdown list to contain the names of all your custom voice services
    - In Settings > Devices & Services > Helpers tab, click CREATE HELPER button and choose `Dropdown`
    - In the `name` field, enter `tts_voices` (this tutorial will assume that the dropdown's entity name will be `input_select.tts_voices`)
    - in the `options` field, add the name of the first voice you want to be able to choose from, prefaced by `script.`, eg. `script.say_as_bob`
    - add the rest of the voices and save the dropdown list.  You can add more voices to this list later.
    - *important*: immediately after your dropdown is created, there might not be any voice selected, and this would cause the script to fail.  Click the tts_voices entity you just created and in the popup window, choose one of your voices from the dropdown list.

2. Create a text input box to hold the demo text you want the TTS engine to say.
    - In Settings > Devices & Services > Helpers tab, click CREATE HELPER button and choose `Text`
    - In the `name` field, enter `text_to_say` (this tutorial will assume that the text entity's name will be `input_text.text_to_say`)
    - click on the newly created entity and in the popup window, enter a test phrase in the text input box and save it.

3. Create a button to say your test phrase in the selected voice. This will be configured later.
    - In Settings > Devices & Services > Helpers tab, click CREATE HELPER button and choose `Button`
    - In the `name` field, enter `say_it` (this tutorial will assume that the button entity's name will be `input_button.say_it`)
    - Click `Create`

4. Create a script that will say the text in your text box using the voice service selected in the dropdown list.
   - In Settings > Automations and Scenes > Scripts tab, click the CREATE SCRIPT button, choose Create new script.
   - From the kebab menu (three vertical dots in the top right corner), choose `Edit in YAML`
   - Delete the line that says `sequence: []`
   - Paste in the following script:
```
sequence:
  - data_template:
      message: "{{ states('input_text.text_to_say') }}"
    action: "{{ states('input_select.tts_voices') }}"
alias: Test TTS
description: Say text in the input box
```
  - Click the SAVE SCRIPT button.  Name this script `test_tts` (this tutorial will assume that this script entity's name will be `scripts.test_tts`)
  - Once your `test_tts` script has been created, you should be able to test it.   Click the kebab menu (three vertical dots) on the line associated with the `test_tts` script, and choose `Run`.  If you have done everything right you should hear your test phrase spoken in the voice you have chosen.

5. Create entities in your lovelace dashboard and configure the button
![image](https://github.com/user-attachments/assets/c3722a12-49a5-4123-aca6-d29cb4dbe9ed)
- In the example above, an `Entities` card was created by putting the dashboard into edit mode, clicking the `+` button, and choosing the `Entities` card from the `BY CARD` tab.
- in the popup window, under `Entities (required)`, delete the example entities, then:
  - Set the first entity to `input_select.tts_voices`
  - Set the second entity to `input_text.text_to_say`
  - Click `Save`
- To add the button, click the `+` button below the dropdown and text box you just added and in the `BY CARD` tab, search for the `Button` card and click it.
- To configure the button, first replace anything in the `Entity` field with the button entity you created earlier (`input_button.say_it`)
- Optionally give your button a name and/or icon.
- In the `Tap behavior` field, choose `Perform action`
- A new `Action` field will appear.  Enter `script.test_tts` here to cause this button to trigger the script you created earlier.
- Change any additional layout options as you wish.  The example above has `Full width card` turned on in the `Layout` tab
- click `SAVE` to save your button.
- click the `DONE` button to stop editing your dashboard.
- You now can say anything in any voice via your home assistant dashboard.   Enjoy!

### Known issues:
- Sometimes the preview button will play the previous message that had been stored in the text box rather than the one you have just typed.  This is because the text box doesn't pass its new value to the rest of the system until it loses focus.  Until I find a way to resolve this, you can click or tap anywhere outside the box after entering a new message before you click the "say" button.





