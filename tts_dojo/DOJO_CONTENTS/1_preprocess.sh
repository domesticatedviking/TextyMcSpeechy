python3 -m piper_train.preprocess \
  --language en-us \
  --input-dir ./target_voice_dataset \
  --output-dir ./training_folder \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 16000
