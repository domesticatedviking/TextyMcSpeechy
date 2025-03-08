# TextyMcSpeechy Dataset Recorder GUI

![TextyMcSpeechy Dataset Recorder](https://github.com/user-attachments/assets/8f68fa74-c36a-4105-af9b-1ab05f3e90b6)

`dataset_recorder_gui.py` is a graphical application that greatly simplifies the process of creating datasets for text-to-speech models. This tool combines the functionality of the original shell scripts (`dataset_recorder.sh`, `new_dataset_recorder.sh`) and the ElevenLabs API integration (`geteleven.py`) into a single, easy-to-use application.

## Features

- **User-friendly graphical interface** - No more command line interactions
- **Audio recording** - Record your voice directly through the application
- **ElevenLabs integration** - Generate synthetic speech for your dataset
- **Waveform visualization** - See your audio recordings in real-time
- **Background noise removal** - Clean up your recordings with built-in room tone removal
- **Progress tracking** - Keep track of your dataset completion status
- **Batch processing** - Generate all missing recordings with a single click

## Getting Started

### Prerequisites

The application requires the following Python packages:
- tkinter (usually included with Python)
- pyaudio
- numpy
- matplotlib
- requests
- python-dotenv

Install the required packages with:

```bash
pip install pyaudio numpy matplotlib requests python-dotenv
```

For the room tone removal feature, you'll also need:
- sox (Sound eXchange)
- ffmpeg

Install these on your system:

```bash
# Ubuntu/Debian
sudo apt install sox ffmpeg

# Arch Linux
sudo pacman -S sox ffmpeg

# Fedora
sudo dnf install sox ffmpeg
```

### Running the Application

Simply run the Python script:

```bash
python dataset_recorder_gui.py
```

## Usage Guide

1. **Open a CSV file** - Use File → Open CSV to select your metadata.csv file
2. **Set output directory** - Choose where to save your WAV files
3. **Record or generate audio** - For each phrase, either:
   - Click "Record" to record your voice
   - Click "Generate with ElevenLabs" to use AI-generated speech (requires API key)
4. **Navigate through phrases** - Use Previous/Next buttons to move through your dataset
5. **Listen to recordings** - Play back your recordings to check quality
6. **Remove background noise** - Use Tools → Remove Room Tone to clean up recordings

## ElevenLabs Integration

To use the ElevenLabs text-to-speech generation:

1. Create an account at [ElevenLabs](https://elevenlabs.io/)
2. Get your API key from your account settings
3. In the application, go to Tools → ElevenLabs Settings
4. Enter your API key and save

## Removing Background Noise

The application includes the room tone removal functionality from the original `remove_roomtone.sh` script:

1. Go to Tools → Remove Room Tone
2. Select your input directory (containing WAV files)
3. Choose an output directory for the cleaned files
4. Provide a room tone file or record one using the "Record Room Tone" button
5. Click "Process" to remove background noise from all recordings

## Tips for Creating Quality Datasets

- Record in a quiet environment to minimize background noise
- Use a good quality microphone positioned consistently
- Speak clearly and at a consistent pace
- Include proper names and phrases you'll be using in your application
- For training Piper models, consider using [pronunciation rules](docs/altering_pronunciation.md) for better results

## Advantages Over the Original Scripts

- Visual feedback with waveform display
- No need to switch between different tools
- Easier navigation through your dataset
- Real-time progress tracking
- Integrated noise removal
- Both recording and AI generation in one tool

This GUI application makes the dataset creation process much more accessible, especially for users who prefer graphical interfaces over command-line tools.
