## How to modify pronunciation 
- Thanks to Thorsten Mueller for this helpful [tutorial](https://www.youtube.com/watch?v=493xbPIQBSU) which gives tips on how to add custom pronunciation rules to `espeak-ng`, which `piper` relies on.
- If you notice that words aren't being pronounced correctly even when they are recorded correctly  in your audio dataset, it is likely because the phonemes supplied by `espeak-ng` are incorrect.
## Creating custom pronunciation rules
- Clone the espeak-ng git repo to get the files you will need to modify:  `git clone https://github.com/espeak-ng/espeak-ng`
- For whichever language(s) you are using, you will need 3 dictionary source files from `espeak-ng/dictsource` (substitute the language code of the language you are modifying for `xx`):  
1. `xx_list`
2. `xx_rules`
3. `xx_emoji`
4. `xx_extra` - this file is not supplied, it is a plain text file that you must create yourself (see below)
- Each line in `xx_extra` begins with the text to be pronounced, followed by the pronunciation as represented in [Kirschenbaum](https://en.wikipedia.org/wiki/Kirshenbaum) format (Also known as ASCII-IPA or erkIPA format).

```
#en_extra file format example
Noella  no'El:V O
```

- I have created an [IPA to kirschenbaum cheatsheet](/docs/IPA_to_kirschenbaum_cheatsheet.md) which may be a useful starting point for people who know the international phonetic alphabet.

## Alternative option - use AI to create your pronunciation file - (thanks D34DC3N73R!)

[D34DC3N73R](https://github.com/D34DC3N73R) reported having great success converting IPA to Kirschenbaum / ASCII IPA using an LLM.
 They also had very good results using an LLM to generate custom pronunciations (ie `en_extra` file entries) for specific accents. 
I haven't tried it yet but this looks like a very promising option.

### Example prompt:
```
I am developing a New York accent voice model for Piper, 
which utilizes eSpeak-NG as its phoneme synthesis engine. 
Provide a list of the 100 words most likely to be mispronounced 
by eSpeak-NG due to the distinct features of the New York accent. 
Display each word in a list with its Kirschenbaum (ASCII-IPA) 
conversion format, as shown in these examples:

garage g@'rA:Z 
smart smA:rt 
sabotage sab@,tA:3 

Do not include any explanations or additional text within the list itself.
```

### Example output:
```
Here is a list of the top 100 words most likely to be mispronounced by eSpeak-NG in a New York accent, 
presented in Kirschenbaum (ASCII-IPA) format without explanations:

coffee k'A:fi
water w'A:t@
dog dA:g
talk tA:k
call kA:l
car kA:
park pA:k
sure S@
door dO:
floor flO:
long lA:Ng
island 'A:l@nd
thought TA:t

etc...

```

## Activating custom pronunciation rules
### For people using the `textymcspeechy-piper` docker image (applies to most users)
- `Espeak-ng` is preinstalled in the `textymcspeechy-piper` docker image.   The commands to compile pronunciation must be run as root within the docker container, and must be run every time the container starts.
- There are scripts for both manually and automatically activating your custom pronunciations provided. Instructions for these are found [here](/tts_dojo/ESPEAK_RULES/README_custom_pronunciation.md). 

### For non-containerized installs of espeak-ng (more convenient for testing):  
- Compile the new pronunciation rule to make it active.
```
  # IMPORTANT-  run this from the directory where xx_list, xx_rules, xx_emoji, and xx_extra are located.

  sudo espeak-ng --compile=xx  # <--- where xx is the 2 letter language code.
```
- Test the new pronunciation, eg  
```
espeak-ng "Testing the corrected pronunciation of Noella" --ipa

espeak-ng -v ja "ピクルス" --ipa

espeak-ng -v ru "Пожалуйста" --ipa
```
- Changes to espeak-ng's pronunciation rules are applied system-wide on non-containerized installs and only have to be applied once.  If you need to undo your custom pronunciations, revise or delete `xx_extra` and compile your rules again as above.

