## How do I use custom voices in Home Assistant scripts?

Once you have a Piper TTS model that you know works, here's how you can make use of it in your own scripts just as easily as any other TTS service.


1. Create a script for your custom voice which accepts a template value as an input. The script below is called `say_as_bob` 
     - note that you need to use your own `media_player_entity_id` and `voice`.  
     - If you need output to go to multiple speakers, you can use a comma separated list (eg:  `media_player_entity_id: media_player.speaker1, media_player.speaker2`). 
     - If running on GPU, be sure to change the entity id to  `tts.piper_gpu` (or whatever name you chose for your wyoming piper GPU entity).
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
