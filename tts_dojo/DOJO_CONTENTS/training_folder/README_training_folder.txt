***The files in this folder will be generated automatically***
You don't need to put anything here, but here's what will be here.

It will contain:
cache           - folder with your target voice samples in .pt format
lightning_logs  - contains the checkpoint files created as your model is trained
                  look for your <epoch=etc>.ckpt fike in lightning_logs/version_<X>/checkpoints
                  (the highest version is the most recent one you have trained)
config.json     - training configuration
dataset.jsonl   - dataset information
