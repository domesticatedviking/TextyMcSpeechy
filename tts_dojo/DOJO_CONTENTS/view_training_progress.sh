#!/bin/sh
echo
echo
echo "View training progress with Tensorboard"
echo 
echo "   open http://localhost:6006 in your web browser while model is training in another terminal window "
echo 
echo "   When the graph for 'loss_disc_all' levels off, your model is ready"
echo
tensorboard --logdir ./training_folder/lightning_logs
echo
