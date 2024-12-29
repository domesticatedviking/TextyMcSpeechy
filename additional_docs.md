## How to modify pronunciation 
- Thanks to Thorsten Mueller for this helpful [tutorial](https://www.youtube.com/watch?v=493xbPIQBSU) which gives tips on how to add custom pronunciation rules to `espeak-ng`, which `piper` relies on.
- If you notice that words aren't being pronounced correctly even when they appear multiple times in your dataset, it is likely because the phonemes supplied by `espeak-ng` are incorrect.
### Basic steps
- ensure that espeak-ng is installed: `dpkg -l|grep -i espeak`
- Clone the git repo to get the files you will need to modify:  `git clone https://github.com/espeak-ng/espeak-ng.git`
- `cd espeak-ng/dictsource`
- create a new file `en_extra`  (if using another language, substitute the language code for `en`)
- add the modified pronunciation rules to `en_extra` and save the file.
- Each line in `en_extra` begins with the text to be pronounced, followed by the pronunciation as represented in [Kirschenbaum](https://en.wikipedia.org/wiki/Kirshenbaum) format (Also known as ASCII-IPA or erkIPA format)

```
#en_extra file format example
Noella  no'El:V O
```

- compile the pronunciation rules to make them active `sudo espeak-ng --compile=en`
- to test the new pronunciation:  `espeak-ng "your text here" --ipa`

