## How to modify pronunciation 
- Thanks to Thorsten Mueller for this helpful [tutorial](https://www.youtube.com/watch?v=493xbPIQBSU) which gives tips on how to add custom pronunciation rules to `espeak-ng`, which `piper` relies on.
- If you notice that words aren't being pronounced correctly even when they are recorded correctly  in your audio dataset, it is likely because the phonemes supplied by `espeak-ng` are incorrect.
### Basic steps
- confirm that espeak-ng is installed: `dpkg -l|grep -i espeak`
- Clone the espeak-ng git repo to get the files you will need to modify:  `git clone https://github.com/espeak-ng/espeak-ng.git`
- Open the directory containing the dictionary source files `cd espeak-ng/dictsource`
- create a new custom pronunciation file named `en_extra`  (if using another language, substitute the language code for `en`)
- add the modified pronunciation rules to `en_extra` and save the file.
- Each line in `en_extra` begins with the text to be pronounced, followed by the pronunciation as represented in [Kirschenbaum](https://en.wikipedia.org/wiki/Kirshenbaum) format (Also known as ASCII-IPA or erkIPA format).

```
#en_extra file format example
Noella  no'El:V O
```
- Compile the new pronunciation rule to make it active.  `sudo espeak-ng --compile=en`
- Test the new pronunciation, eg  `espeak-ng "Testing the corrected pronunciation of Noella" --ipa`
- Changes to espeak-ng's pronunciation rules are applied system-wide.
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

