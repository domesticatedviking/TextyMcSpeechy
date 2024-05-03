BIN_DIR=$(cat .BIN_DIR)
echo "BIN_DIR= '$BIN_DIR'"
DOJO_DIR=$(cat .DOJO_DIR)
echo "DOJO_DIR = '$DOJO_DIR'"
PIPER_PATH=$(cat .PIPER_PATH)
echo "PIPER_PATH = '$PIPER_PATH'"
VOICE_NAME=$(cat .VOICE_NAME)
echo "VOICE_NAME = '$VOICE_NAME'"

mkdir $DOJO_DIR/finished_tts_voice/$VOICE_NAME
cd $PIPER_PATH
python3 -m piper_train.export_onnx \
    $DOJO_DIR/training_folder/lightning_logs/version_0/checkpoints/*.ckpt \
    $DOJO_DIR/finished_tts_voice/$VOICE_NAME/$VOICE_NAME.onnx

cp $DOJO_DIR/training_folder/config.json $DOJO_DIR/finished_tts_voice/$VOICE_NAME/$VOICE_NAME.onnx.json
echo
echo "All done.  Your completed TTS model is in $DOJO_DIR/finished_tts_voice/$VOICE_NAME and is ready to use."


