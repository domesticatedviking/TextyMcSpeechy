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
