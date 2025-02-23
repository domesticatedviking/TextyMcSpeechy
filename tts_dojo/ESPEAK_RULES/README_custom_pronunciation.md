## Using custom espeak-ng pronunciations with textymcspeechy-piper docker container
- `espeak-ng` is a package that Piper uses to convert words into phonemes (symbols describing the way the word sounds).  It is preinstalled in the `textymcspeechy-piper` docker container
- These rules impact pronunciation both when training TTS models and when rendering words.
- The `tts_dojo/ESPEAK_RULES` folder must contain all the rule files for your chosen language(s) from [espeak-ng/dictsource](https://github.com/espeak-ng/espeak-ng/tree/master/dictsource) as well as a `<language>_extra` file (eg. `en_extra`) which you must create yourself. 
- the files that are required in the `ESPEAK_RULES` folder for each language you wish to customize are:   `en_list`, `en_rules`, `en_emoji`, `en_extra`.  The first 3 files can be downloaded for all supported languages [here](https://github.com/espeak-ng/espeak-ng/tree/master/dictsource).  You have to create `en_extra` yourself (read on for instructions)
- the language code is the prefix of the filename of the rule file  (for the files above the language code is `en`)

- Typically when you compile rules for `espeak-ng`, those rules are applied globally and are permanent. However, due to the nature of docker containers, you will need to apply your custom ruleset every time your container runs.  You can do this automatically by editing  `ESPEAK_RULES/automated_espeak_rules.sh`
```
# TextyMcSpeechy/tts_dojo/ESPEAK_RULES/automated_espeak_rules.sh

# ALWAYS_CONFIGURE_LANGUAGES determines which ruleset(s) will be compiled when the container starts.
#    eg: "en"     - compiles english ruleset   
#    eg: "en it"  - compiles english and italian rulesets

ALWAYS_CONFIGURE_LANGUAGES="en it"    <--- EDIT THIS LINE TO CHOOSE WHICH CUSTOM RULES WILL AUTOMATICALLY BE APPLIED

# AUTO_APPLY_CUSTOM_ESPEAK_RULES turns rule processing on and off
#  true: automatically apply rules for configured languages when container starts 
# false: do not automatically apply these rules  

AUTO_APPLY_CUSTOM_ESPEAK_RULES="true"  <--- EDIT THIS LINE TO TURN AUTOMATIC LOADING OF RULESETS ON/OFF
```

## Creating a custom pronunciation file (eg.`en_extra`)
- Each line in `en_extra` begins with the text to be pronounced, followed by its phonetic representation in [Kirschenbaum](https://en.wikipedia.org/wiki/Kirshenbaum) format (Also known as ASCII-IPA or erkIPA format).

```
#en_extra file format example
Noella  no'El:V O
```
Please check out this useful [guide to producing custom espeak pronunciations](/docs/altering_pronunciation.md), now with tips for using AI to generate your pronunciation files.


## Purpose of scripts in this folder
  1. `apply_custom_rules.sh`: Runs `container_apply_custom_rules.sh` inside the `textymcspeechy-piper` docker container as root.
  2. `container_apply_custom_rules.sh`:  compiles the ruleset for espeak-ng.  Must run as root inside the docker container.  
  3. `automated_espeak_rules.sh`:   run by the container startup scripts eg `prebuilt_container_run.sh` to make sure your custom rules are applied every time a container launches.

##  Manual Usage:
```
# Run this command on the host computer to manually apply a ruleset to a running textymcspeechy-piper container.

./apply_custom_rules.sh en    # substitute other language codes for en as needed. 
```
   
