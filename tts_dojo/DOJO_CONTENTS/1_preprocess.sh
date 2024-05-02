python3 -m piper_train.preprocess \
  --language en-us \
  --input-dir ./optimusv2 \
  --output-dir ./optimusv2_trained \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 16000
