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

