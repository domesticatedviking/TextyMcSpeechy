# Investigating Piper's multi language support

## What I have determined so far

- Piper uses two different language codes in `.onnx.json` files.
- The first is the espeak voice identifier.
- The second is the BCP-47 language code which is required to be used as the first part of a piper voice's file name
- The data in the "language" field seems like it is mostly used for sorting and selecting voices in menus.
- Obviously the espeak voice identifier is here because it is used to configure the generation of phonemes.
- But where does piper get this identifer from?

```
{
  "dataset": "kareem",
  "audio": {
    "sample_rate": 16000,
    "quality": "low"
  },
  "espeak": {
    "voice": "ar"            <----This is the espeak voice identifier 
  },
  "language": {
    "code": "ar_JO",         <----This is the BCP-47 language code 
    "family": "ar",               Its components seem to be broken down
    "region": "JO",               on the next two lines
    "name_native": "العربية",
    "name_english": "Arabic",
    "country_english": "Jordan"
  },
  "inference": {
    "noise_scale": 0.667,
    "length_scale": 1,
    "noise_w": 0.8
  },
  "phoneme_type": "espeak",
  "phoneme_map": {},
  "phoneme_id_map": {

```

The espeak identifier seems to be mainly of interest during preprocessing.
per the piper docs:
`The --language argument refers to an espeak-ng voice by default, such as de for German.`

So the language code below is NOT the BCP-47 language code, but rather the espeak identifier
```
python3 -m piper_train.preprocess \
  --language en-us \
  --input-dir /path/to/dataset_dir/ \
  --output-dir /path/to/training_dir/ \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 22050
```


## Espeak-ng language identifier table

| Idenfifier    | Language                         |
|---------|----------------------------------|
| af      | Afrikaans                        |
| sq      | Albanian                         |
| am      | Amharic                          |
| ar      | Arabic                           |
| an      | Aragonese                        |
| hy      | Armenian - East Armenian         |
| hyw     | Armenian - West Armenian        |
| as      | Assamese                         |
| az      | Azerbaijani                      |
| ba      | Bashkir                          |
| cu      | Chuvash                          |
| eu      | Basque                           |
| be      | Belarusian                       |
| bn      | Bengali                          |
| bpy     | Bishnupriya Manipuri             |
| bs      | Bosnian                          |
| bg      | Bulgarian                        |
| my      | Burmese                          |
| ca      | Catalan                          |
| chr     | Cherokee - Western/C.E.D.       |
| yue     | Chinese - Cantonese              |
| hak     | Chinese - Hakka                  |
| haw     | Hawaiian                         |
| cmn     | Chinese - Mandarin               |
| hr      | Croatian                         |
| cs      | Czech                            |
| da      | Danish                           |
| nl      | Dutch                            |
| en-us   | English - American               |
| en      | English - British                |
| en-029  | English - Caribbean              |
| en-gb-x-gbclan | English - Lancastrian     |
| en-gb-x-rp     | English - Received Pronunciation |
| en-gb-scotland | English - Scottish       |
| en-gb-x-gbcwmd | English - West Midlands  |
| eo      | Esperanto                        |
| et      | Estonian                         |
| fa      | Persian                          |
| fa-latn | Persian                          |
| fi      | Finnish                          |
| fr-be   | French - Belgium                 |
| fr      | French - France                  |
| fr-ch   | French - Switzerland             |
| ga      | Gaelic - Irish                   |
| gd      | Gaelic - Scottish                |
| ka      | Georgian                         |
| de      | German                           |
| grc     | Greek - Ancient                  |
| el      | Greek - Modern                   |
| kl      | Greenlandic                      |
| gn      | Guarani                          |
| gu      | Gujarati                         |
| ht      | Hatian Creole                    |
| he      | Hebrew                           |
| hi      | Hindi                            |
| hu      | Hungarian                        |
| is      | Icelandic                        |
| id      | Indonesian                       |
| ia      | Interlingua                      |
| io      | Ido                              |
| it      | Italian                          |
| ja      | Japanese                         |
| kn      | Kannada                          |
| kok     | Konkani                          |
| ko      | Korean                           |
| ku      | Kurdish                          |
| kk      | Kazakh                           |
| ky      | Kyrgyz                           |
| la      | Latin                            |
| lb      | Luxembourgish                    |
| ltg     | Latgalian                        |
| lv      | Latvian                          |
| lfn     | Lingua Franca Nova               |
| lt      | Lithuanian                       |
| jbo     | Lojban                           |
| mi      | Māori                            |
| mk      | Macedonian                       |
| ms      | Malay                            |
| ml      | Malayalam                        |
| mt      | Maltese                          |
| mr      | Marathi                          |
| nci     | Nahuatl - Classical              |
| ne      | Nepali                           |
| nb      | Norwegian Bokmål                 |
| nog     | Nogai                            |
| or      | Oriya                            |
| om      | Oromo                            |
| pap     | Papiamento                       |
| py      | Pyash                            |
| pl      | Polish                           |
| pt-br   | Portuguese - Brazilian           |
| qdb     | Lang Belta                       |
| qu      | Quechua                          |
| quc     | K'iche'                          |
| qya     | Quenya                           |
| pt      | Portuguese - Portugal            |
| pa      | Punjabi                          |
| piqd    | Klingon                          |
| ro      | Romanian                         |
| ru      | Russian                          |
| ru-lv   | Russian - Latvia                 |
| uk      | Ukrainian                        |
| sjn     | Sindarin                         |
| sr      | Serbian                          |
| tn      | Setswana                         |
| sd      | Sindhi                           |
| shn     | Shan (Tai Yai)                   |
| si      | Sinhala                          |

- The SETTINGS_ESPEAK_LANGUAGE variable in `DOJO_CONTENTS/scripts/SETTINGS.txt` is already a way of configuring the espeak identifier used by preprocessing, but it seems like a better way of managing this would be for the user to assign one of these codes when packaging their dataset, and having it stored in `dataset.conf`.   Will need to refresh my memory on the way that the hidden file `.ESPEAK_LANGUAGE` which gets created in `PRETRAINED_CHECKPOINTS/default` is used.   Should probably revamp the path structure of `PRETRAINED_CHECKPOINTS` to allow storage of more than one language as well. 
