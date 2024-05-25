#!/bin/sh
DOJO_DIR=$(cat .DOJO_DIR)
clear
echo "   View training progress with Tensorboard"
echo "   open http://localhost:6006 in your web browser"
echo    

tensorboard --logdir $DOJO_DIR/training_folder/lightning_logs >/dev/null 2>&1 
echo
