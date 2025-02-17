# Using custom espeak-ng pronunciations with textymcspeechy-piper docker container
- `espeak-ng` is a package that Piper uses to convert words into phonemes (symbols describing the way the word sounds).  It is preinstalled in the `textymcspeechy-piper` docker container
- These rules impact pronunciation both when training TTS models and when rendering words.
- The `tts_dojo/ESPEAK_RULES` folder must contain all the rule files for your chosen language from [espeak-ng/dictsource](https://github.com/espeak-ng/espeak-ng/tree/master/dictsource) as well as a `<language>_extra` file which you must create yourself.
- for English models, the files that are required in this folder are:  `en_list`, `en_rules`, `en_emoji`, `en_extra`
- the language code is the prefix of the rule file (for the files above the language code is `en`)

- Typically when you compile rules for `espeak-ng`, those rules are applied globally and are permanent. However, due to the nature of docker containers, you will need to apply your custom ruleset every time your container runs.  You can do this automatically by editing the constants in `TextyMcSpeechy/prebuilt_container_run.sh`
```
# TextyMcSpeechy/prebuilt_container_run.sh

APPLY_CUSTOM_ESPEAK_RULES=true`
CUSTOM_ESPEAK_RULES_LANGUAGE="en"  #use the language code for your ruleset
APPLY_CUSTOM_RULESET_SCRIPT="tts_dojo/ESPEAK_RULES/apply_custom_rules.sh $CUSTOM_ESPEAK_RULES_LANGUAGE"
```

## Creating a custom pronunciation file (eg.`en_extra`)
- Each line in `en_extra` begins with the text to be pronounced, followed by its phonetic representation in [Kirschenbaum](https://en.wikipedia.org/wiki/Kirshenbaum) format (Also known as ASCII-IPA or erkIPA format).

```
#en_extra file format example
Noella  no'El:V O
```

- I have created an [IPA to kirschenbaum cheatsheet](/docs/IPA_to_kirschenbaum_cheatsheet.md) which will help you convert ipa pronunciatiions to the format espeak-ng needs.
- [This site](https://www.internationalphoneticalphabet.org/ipa-sounds/ipa-chart-with-sounds/) is a great reference for IPA.  You can click on each symbol to hear how it sounds, which will help you choose the symbols that represent the sounds of your target word.
- [This site](https://ipa-reader.com/) is useful for testing IPA transcriptions.




## Purpose of scripts in this folder
  1. `apply_custom_rules.sh`: Runs `container_apply_custom_rules.sh` inside the `textymcspeechy-piper` docker container as root.
  2. `container_apply_custom_rules.sh`:  compiles the ruleset for espeak-ng in the docker container.

## Example Usage:
```
# Run this command on the host computer
./apply_custom_rules.sh en    # substitute other language codes for en as needed. 
```
   
