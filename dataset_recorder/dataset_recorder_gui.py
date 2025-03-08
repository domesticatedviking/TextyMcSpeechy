#!/usr/bin/env python3
"""
TextyMcSpeechy Dataset Recorder GUI
A graphical tool for recording and generating datasets for text-to-speech models.
Combines functionality from dataset_recorder.sh, new_dataset_recorder.sh, and geteleven.py.
"""

import os
import sys
import csv
import time
import wave
import json
import threading
import subprocess
import tempfile
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
import pyaudio
import requests
import numpy as np
from dotenv import load_dotenv
from matplotlib.figure import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import io

# Constants
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 44100
MAX_RECORDING_SECONDS = 30
TRIM_SILENCE_MS = 50  # Milliseconds to trim from start and end
VOICE_ID = "H6Ti9LTHoVP3jUkb7KKg" # ElevenLabs Voice ID
PCM_SAMPLE_RATE = 22050  # ElevenLabs PCM sample rate

# Keyboard shortcuts
SHORTCUT_PREV = "Left"       # Previous item
SHORTCUT_NEXT = "Right"      # Next item
SHORTCUT_RECORD = "r"        # Record/stop recording
SHORTCUT_PLAY = "space"      # Play/stop playback
SHORTCUT_GENERATE = "g"      # Generate with ElevenLabs
SHORTCUT_GENERATE_ALL = "a"  # Generate all missing

class DatasetRecorder:
    def __init__(self, root):
        self.root = root
        self.root.title("TextyMcSpeechy Dataset Recorder")
        self.root.geometry("1000x700")
        self.root.minsize(800, 600)

        # Set up variables
        self.output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wav")
        self.csv_file = ""
        self.filenames = []
        self.phrases = []
        self.recorded = []
        self.current_index = 0
        self.is_recording = False
        self.recording_thread = None
        self.stream = None
        self.p = None
        self.frames = []
        self.waveform_data = []
        self.elevenlabs_api_key = os.getenv("ELEVENLABS_API_KEY", "")

        # Audio playback variables
        self.is_playing = False
        self.play_thread = None
        self.play_stream = None

        # Load environment variables
        load_dotenv()
        self.elevenlabs_api_key = os.getenv("ELEVENLABS_API_KEY", "")

        # Create main frame
        self.main_frame = ttk.Frame(self.root, padding="10")
        self.main_frame.pack(fill=tk.BOTH, expand=True)

        # Create menu bar
        self.create_menu()

        # Create UI components
        self.create_ui()

        # Initialize audio
        self.init_audio()

        # Check if output directory exists, create if not
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

        # Bind keyboard shortcuts
        self.bind_shortcuts()

        # Bind window close event
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

    def bind_shortcuts(self):
        """Bind keyboard shortcuts to actions"""
        self.root.bind(f"<{SHORTCUT_PREV}>", lambda e: self.previous_item())
        self.root.bind(f"<{SHORTCUT_NEXT}>", lambda e: self.next_item())
        self.root.bind(f"<{SHORTCUT_RECORD}>", lambda e: self.toggle_recording())
        self.root.bind(f"<{SHORTCUT_PLAY}>", lambda e: self.play_audio())
        self.root.bind(f"<{SHORTCUT_GENERATE}>", lambda e: self.generate_audio())
        self.root.bind(f"<{SHORTCUT_GENERATE_ALL}>", lambda e: self.generate_all_missing())

    def create_menu(self):
        menubar = tk.Menu(self.root)

        # File menu
        file_menu = tk.Menu(menubar, tearoff=0)
        file_menu.add_command(label="Open CSV", command=self.open_csv)
        file_menu.add_command(label="Set Output Directory", command=self.set_output_dir)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.on_closing)
        menubar.add_cascade(label="File", menu=file_menu)

        # Tools menu
        tools_menu = tk.Menu(menubar, tearoff=0)
        tools_menu.add_command(label="Remove Room Tone", command=self.show_room_tone_dialog)
        tools_menu.add_command(label="ElevenLabs Settings", command=self.show_elevenlabs_settings)
        menubar.add_cascade(label="Tools", menu=tools_menu)

        # Help menu
        help_menu = tk.Menu(menubar, tearoff=0)
        help_menu.add_command(label="About", command=self.show_about)
        menubar.add_cascade(label="Help", menu=help_menu)

        self.root.config(menu=menubar)

    def create_ui(self):
        # Top frame for CSV info and navigation
        top_frame = ttk.Frame(self.main_frame)
        top_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Label(top_frame, text="CSV File:").pack(side=tk.LEFT, padx=(0, 5))
        self.csv_label = ttk.Label(top_frame, text="No file selected")
        self.csv_label.pack(side=tk.LEFT, padx=(0, 10))

        ttk.Label(top_frame, text="Output Dir:").pack(side=tk.LEFT, padx=(10, 5))
        self.output_dir_label = ttk.Label(top_frame, text=self.output_dir)
        self.output_dir_label.pack(side=tk.LEFT)

        # Progress frame
        progress_frame = ttk.Frame(self.main_frame)
        progress_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Label(progress_frame, text="Progress:").pack(side=tk.LEFT, padx=(0, 5))
        self.progress_var = tk.StringVar(value="0/0")
        ttk.Label(progress_frame, textvariable=self.progress_var).pack(side=tk.LEFT, padx=(0, 10))

        self.progress_bar = ttk.Progressbar(progress_frame, orient=tk.HORIZONTAL, length=300, mode='determinate')
        self.progress_bar.pack(side=tk.LEFT, padx=(10, 0), fill=tk.X, expand=True)

        # Text display frame
        text_frame = ttk.LabelFrame(self.main_frame, text="Current Phrase")
        text_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 10))

        self.phrase_text = scrolledtext.ScrolledText(text_frame, wrap=tk.WORD, height=5, font=('TkDefaultFont', 12))
        self.phrase_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        self.phrase_text.config(state=tk.DISABLED)

        # Waveform display
        waveform_frame = ttk.LabelFrame(self.main_frame, text="Audio Waveform")
        waveform_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 10))

        self.fig = Figure(figsize=(5, 2), dpi=100)
        self.ax = self.fig.add_subplot(111)
        self.ax.set_ylim(-32768, 32768)
        self.ax.set_xlim(0, 1)
        self.ax.set_yticks([])
        self.ax.set_xticks([])
        self.ax.set_title("No Audio")

        self.canvas = FigureCanvasTkAgg(self.fig, master=waveform_frame)
        self.canvas.draw()
        self.canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)

        # Control buttons frame
        control_frame = ttk.Frame(self.main_frame)
        control_frame.pack(fill=tk.X, pady=(0, 10))

        # Navigation buttons
        nav_frame = ttk.Frame(control_frame)
        nav_frame.pack(side=tk.LEFT, padx=(0, 10))

        self.prev_btn = ttk.Button(nav_frame, text=f"Previous ({SHORTCUT_PREV})", command=self.previous_item, state=tk.DISABLED)
        self.prev_btn.pack(side=tk.LEFT, padx=(0, 5))

        # Current item display
        self.item_var = tk.StringVar(value="0/0")
        ttk.Label(nav_frame, textvariable=self.item_var, width=8, anchor=tk.CENTER,
                 font=('TkDefaultFont', 10, 'bold')).pack(side=tk.LEFT, padx=5)

        self.next_btn = ttk.Button(nav_frame, text=f"Next ({SHORTCUT_NEXT})", command=self.next_item, state=tk.DISABLED)
        self.next_btn.pack(side=tk.LEFT)

        # Action buttons
        action_frame = ttk.Frame(control_frame)
        action_frame.pack(side=tk.LEFT)

        self.record_btn = ttk.Button(action_frame, text=f"Record ({SHORTCUT_RECORD})",
                                    command=self.toggle_recording, state=tk.DISABLED)
        self.record_btn.pack(side=tk.LEFT, padx=(0, 5))

        self.play_btn = ttk.Button(action_frame, text=f"Play ({SHORTCUT_PLAY})",
                                  command=self.play_audio, state=tk.DISABLED)
        self.play_btn.pack(side=tk.LEFT, padx=(0, 5))

        self.generate_btn = ttk.Button(action_frame, text=f"Generate with ElevenLabs ({SHORTCUT_GENERATE})",
                                      command=self.generate_audio, state=tk.DISABLED)
        self.generate_btn.pack(side=tk.LEFT, padx=(0, 5))

        self.generate_all_btn = ttk.Button(action_frame, text=f"Generate All Missing ({SHORTCUT_GENERATE_ALL})",
                                          command=self.generate_all_missing, state=tk.DISABLED)
        self.generate_all_btn.pack(side=tk.LEFT)

        # Status bar
        self.status_var = tk.StringVar(value="Ready")
        self.status_bar = ttk.Label(self.main_frame, textvariable=self.status_var, relief=tk.SUNKEN, anchor=tk.W)
        self.status_bar.pack(fill=tk.X, side=tk.BOTTOM)

    def init_audio(self):
        """Initialize PyAudio"""
        self.p = pyaudio.PyAudio()

    def open_csv(self):
        """Open a CSV file and load its contents"""
        file_path = filedialog.askopenfilename(
            title="Select CSV File",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")]
        )

        if file_path:
            self.csv_file = file_path
            self.csv_label.config(text=os.path.basename(file_path))
            self.load_metadata(file_path)
            self.check_files()
            self.update_ui()
            self.status_var.set(f"Loaded {len(self.filenames)} items from {os.path.basename(file_path)}")

    def set_output_dir(self):
        """Set the output directory for WAV files"""
        dir_path = filedialog.askdirectory(
            title="Select Output Directory",
            initialdir=self.output_dir
        )

        if dir_path:
            self.output_dir = dir_path
            self.output_dir_label.config(text=dir_path)
            if self.filenames:
                self.check_files()
                self.update_ui()

            # Create directory if it doesn't exist
            if not os.path.exists(self.output_dir):
                os.makedirs(self.output_dir)

    def load_metadata(self, csv_file):
        """Load metadata from CSV file"""
        self.filenames = []
        self.phrases = []
        self.recorded = []

        try:
            with open(csv_file, 'r', encoding='utf-8') as f:
                line_number = 0
                for line in f:
                    if not line.strip():
                        continue

                    parts = line.strip().split('|')
                    if len(parts) < 2 or not parts[0] or not parts[1]:
                        continue

                    line_number += 1
                    filename = f"{parts[0]}.wav"
                    phrase = f"{line_number}. {parts[1]}"

                    self.filenames.append(filename)
                    self.phrases.append(phrase)
                    self.recorded.append(False)

            self.current_index = 0
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load CSV file: {e}")

    def check_files(self):
        """Check which files have already been recorded"""
        for i, filename in enumerate(self.filenames):
            path = os.path.join(self.output_dir, filename)
            self.recorded[i] = os.path.isfile(path)

        # Find first unrecorded item
        for i, recorded in enumerate(self.recorded):
            if not recorded:
                self.current_index = i
                break

    def update_ui(self):
        """Update UI elements based on current state"""
        # Update progress
        total = len(self.filenames)
        recorded = sum(self.recorded)
        self.progress_var.set(f"{recorded}/{total}")

        if total > 0:
            self.progress_bar["maximum"] = total
            self.progress_bar["value"] = recorded

            # Update current item display
            self.item_var.set(f"{self.current_index + 1}/{total}")

        # Update phrase text
        if self.filenames:
            self.phrase_text.config(state=tk.NORMAL)
            self.phrase_text.delete(1.0, tk.END)

            if 0 <= self.current_index < len(self.phrases):
                # Remove the line number prefix for cleaner display
                display_text = self.phrases[self.current_index]
                if '. ' in display_text:
                    display_text = display_text.split('. ', 1)[1]
                self.phrase_text.insert(tk.END, display_text)

            self.phrase_text.config(state=tk.DISABLED)

        # Update buttons
        has_files = len(self.filenames) > 0
        self.record_btn.config(state=tk.NORMAL if has_files else tk.DISABLED)
        self.prev_btn.config(state=tk.NORMAL if self.current_index > 0 else tk.DISABLED)
        self.next_btn.config(state=tk.NORMAL if self.current_index < len(self.filenames) - 1 else tk.DISABLED)

        # Update play button
        current_file = os.path.join(self.output_dir, self.filenames[self.current_index]) if self.filenames else None
        self.play_btn.config(state=tk.NORMAL if current_file and os.path.isfile(current_file) else tk.DISABLED)

        # Update generate buttons
        has_elevenlabs_key = bool(self.elevenlabs_api_key)
        self.generate_btn.config(state=tk.NORMAL if has_files and has_elevenlabs_key else tk.DISABLED)
        self.generate_all_btn.config(state=tk.NORMAL if has_files and has_elevenlabs_key else tk.DISABLED)

        # Load waveform if file exists
        if current_file and os.path.isfile(current_file):
            self.load_waveform(current_file)
        else:
            self.clear_waveform()

    def toggle_recording(self):
        """Start or stop recording"""
        # Only allow recording if the button is enabled
        if self.record_btn.cget('state') == tk.DISABLED:
            return

        if self.is_recording:
            self.stop_recording()
        else:
            self.start_recording()

    def start_recording(self):
        """Start recording audio"""
        if self.is_recording:
            return

        self.is_recording = True
        self.record_btn.config(text=f"Stop Recording ({SHORTCUT_RECORD})")
        self.frames = []
        self.waveform_data = []

        # Disable navigation while recording
        self.prev_btn.config(state=tk.DISABLED)
        self.next_btn.config(state=tk.DISABLED)

        # Start recording in a separate thread
        self.recording_thread = threading.Thread(target=self.record_audio)
        self.recording_thread.daemon = True
        self.recording_thread.start()

        # Start updating waveform
        self.update_waveform_while_recording()

    def record_audio(self):
        """Record audio in a separate thread"""
        try:
            self.stream = self.p.open(
                format=FORMAT,
                channels=CHANNELS,
                rate=RATE,
                input=True,
                frames_per_buffer=CHUNK
            )

            self.status_var.set("Recording... Press 'Stop Recording' when done")

            for _ in range(0, int(RATE / CHUNK * MAX_RECORDING_SECONDS)):
                if not self.is_recording:
                    break

                data = self.stream.read(CHUNK)
                self.frames.append(data)

                # Convert to numpy array for waveform display
                audio_data = np.frombuffer(data, dtype=np.int16)
                self.waveform_data.extend(audio_data)

            # Stop recording if max time reached
            if self.is_recording:
                self.root.after(0, self.stop_recording)

        except Exception as e:
            self.status_var.set(f"Error recording: {e}")
            self.root.after(0, self.stop_recording)

    def update_waveform_while_recording(self):
        """Update the waveform display while recording"""
        if not self.is_recording:
            return

        if self.waveform_data:
            self.ax.clear()
            self.ax.set_ylim(-32768, 32768)

            # Only show the last ~3 seconds of audio for a moving display
            samples_to_show = min(len(self.waveform_data), RATE * 3)
            data_to_plot = self.waveform_data[-samples_to_show:]

            self.ax.plot(range(len(data_to_plot)), data_to_plot, color='blue')
            self.ax.set_xticks([])
            self.ax.set_yticks([])
            self.ax.set_title("Recording...")
            self.canvas.draw()

        # Schedule the next update
        self.root.after(100, self.update_waveform_while_recording)

    def stop_recording(self):
        """Stop recording and save the audio file"""
        if not self.is_recording:
            return

        self.is_recording = False
        self.record_btn.config(text=f"Record ({SHORTCUT_RECORD})")

        # Close the audio stream
        if self.stream:
            self.stream.stop_stream()
            self.stream.close()
            self.stream = None

        # Save the recorded audio
        if self.frames and self.current_index < len(self.filenames):
            filename = self.filenames[self.current_index]
            output_path = os.path.join(self.output_dir, filename)

            try:
                # Save the WAV file
                wf = wave.open(output_path, 'wb')
                wf.setnchannels(CHANNELS)
                wf.setsampwidth(self.p.get_sample_size(FORMAT))
                wf.setframerate(RATE)
                wf.writeframes(b''.join(self.frames))
                wf.close()

                # Trim silence from the beginning and end
                # self.trim_wav(output_path)

                self.recorded[self.current_index] = True
                self.status_var.set(f"Saved recording to {filename}")

            except Exception as e:
                self.status_var.set(f"Error saving recording: {e}")

        # Re-enable navigation
        self.update_ui()

    def trim_wav(self, file_path):
        # FIXME: this is broken
        """Trim silence from the beginning and end of a WAV file"""
        try:
            # Create a temporary file
            temp_fd, temp_path = tempfile.mkstemp(suffix='.wav')
            os.close(temp_fd)

            # Get the duration
            result = subprocess.run(
                ['ffprobe', '-i', file_path, '-show_entries', 'format=duration',
                 '-v', 'quiet', '-of', 'csv=p=0'],
                capture_output=True, text=True
            )

            if result.returncode != 0:
                raise Exception("Failed to get audio duration")

            duration = float(result.stdout.strip())
            trim_sec = TRIM_SILENCE_MS / 1000.0
            new_duration = duration - (trim_sec * 2)

            if new_duration <= 0:
                self.status_var.set("Audio too short to trim, keeping original")
                return

            # Trim using ffmpeg - use pcm_s16le codec to ensure WAV compatibility
            subprocess.run(
                ['ffmpeg', '-y', '-i', file_path, '-ss', f'00:00:00.{TRIM_SILENCE_MS:03d}',
                 '-t', str(new_duration), '-acodec', 'pcm_s16le', '-ar', str(RATE),
                 '-ac', str(CHANNELS), temp_path],
                capture_output=True, check=True
            )

            # Replace the original file
            os.remove(file_path)
            os.rename(temp_path, file_path)

            # Load the trimmed waveform
            self.load_waveform(file_path)

        except subprocess.CalledProcessError as e:
            self.status_var.set(f"Error trimming audio: {e.stderr.decode() if e.stderr else e}")
        except Exception as e:
            self.status_var.set(f"Error trimming audio: {e}")

    def load_waveform(self, file_path):
        """Load and display a waveform from a WAV file"""
        try:
            # Check if the file is a valid WAV file
            if not os.path.exists(file_path):
                raise FileNotFoundError(f"File not found: {file_path}")

            # Use ffmpeg to convert the file to raw PCM data for visualization
            # This is more robust than using wave.open directly
            temp_fd, temp_path = tempfile.mkstemp(suffix='.raw')
            os.close(temp_fd)

            try:
                # Convert to raw PCM using ffmpeg
                result = subprocess.run(
                    ['ffmpeg', '-y', '-i', file_path, '-f', 's16le', '-acodec', 'pcm_s16le',
                     '-ar', str(RATE), '-ac', '1', temp_path],
                    capture_output=True, check=True
                )

                # Read the raw PCM data
                with open(temp_path, 'rb') as f:
                    raw_data = f.read()

                # Convert to numpy array
                audio_data = np.frombuffer(raw_data, dtype=np.int16)

                # Limit to first 10 seconds for display
                max_samples = 10 * RATE
                if len(audio_data) > max_samples:
                    audio_data = audio_data[:max_samples]

                # Plot the waveform
                self.ax.clear()
                self.ax.set_ylim(-32768, 32768)
                self.ax.plot(range(len(audio_data)), audio_data, color='green')
                self.ax.set_xticks([])
                self.ax.set_yticks([])
                self.ax.set_title(os.path.basename(file_path))
                self.canvas.draw()

            finally:
                # Clean up temp file
                if os.path.exists(temp_path):
                    os.unlink(temp_path)

        except subprocess.CalledProcessError as e:
            self.status_var.set(f"Error processing audio file: {e.stderr.decode() if e.stderr else e}")
            self.clear_waveform()
        except Exception as e:
            self.status_var.set(f"Error loading waveform: {e}")
            self.clear_waveform()

    def clear_waveform(self):
        """Clear the waveform display"""
        self.ax.clear()
        self.ax.set_ylim(-32768, 32768)
        self.ax.set_xlim(0, 1)
        self.ax.set_yticks([])
        self.ax.set_xticks([])
        self.ax.set_title("No Audio")
        self.canvas.draw()

    def play_audio(self):
        """Play the current audio file using PyAudio"""
        # Only allow playing if the button is enabled
        if self.play_btn.cget('state') == tk.DISABLED:
            return

        if self.is_playing:
            self.stop_playback()
            return

        if self.current_index < len(self.filenames):
            filename = self.filenames[self.current_index]
            file_path = os.path.join(self.output_dir, filename)

            if os.path.isfile(file_path):
                try:
                    # Change button text
                    self.play_btn.config(text=f"Stop Playback ({SHORTCUT_PLAY})")
                    self.is_playing = True

                    # Start playback in a separate thread
                    self.play_thread = threading.Thread(
                        target=self.play_audio_thread,
                        args=(file_path,),
                        daemon=True
                    )
                    self.play_thread.start()

                    self.status_var.set(f"Playing {filename}")

                    # Check if playback has finished
                    self.root.after(100, self.check_playback_finished)

                except Exception as e:
                    self.status_var.set(f"Error playing audio: {e}")
                    self.is_playing = False
                    self.play_btn.config(text=f"Play ({SHORTCUT_PLAY})")

    def play_audio_thread(self, file_path):
        """Thread function for audio playback"""
        try:
            # Open the WAV file
            with wave.open(file_path, 'rb') as wf:
                # Create PyAudio stream for playback
                self.play_stream = self.p.open(
                    format=self.p.get_format_from_width(wf.getsampwidth()),
                    channels=wf.getnchannels(),
                    rate=wf.getframerate(),
                    output=True
                )

                # Read data in chunks and play
                chunk_size = 1024
                data = wf.readframes(chunk_size)

                while data and self.is_playing:
                    self.play_stream.write(data)
                    data = wf.readframes(chunk_size)

                # Clean up
                self.play_stream.stop_stream()
                self.play_stream.close()
                self.play_stream = None

        except Exception as e:
            print(f"Error in playback thread: {e}", file=sys.stderr)

        finally:
            self.is_playing = False

    def check_playback_finished(self):
        """Check if audio playback has finished and update UI accordingly"""
        if not self.is_playing:
            self.play_btn.config(text=f"Play ({SHORTCUT_PLAY})")
        else:
            # Check again after a short delay
            self.root.after(100, self.check_playback_finished)

    def stop_playback(self):
        """Stop audio playback"""
        if self.is_playing:
            self.is_playing = False

            # Wait for playback thread to finish
            if self.play_thread and self.play_thread.is_alive():
                self.play_thread.join(0.5)  # Wait up to 0.5 seconds

            # Close the stream if it's still open
            if self.play_stream:
                self.play_stream.stop_stream()
                self.play_stream.close()
                self.play_stream = None

            self.play_btn.config(text=f"Play ({SHORTCUT_PLAY})")
            self.status_var.set("Playback stopped")

    def previous_item(self):
        """Navigate to the previous item"""
        if self.prev_btn.cget('state') == tk.DISABLED:
            return

        if self.current_index > 0:
            self.current_index -= 1
            self.update_ui()

    def next_item(self):
        """Navigate to the next item"""
        if self.next_btn.cget('state') == tk.DISABLED:
            return

        if self.current_index < len(self.filenames) - 1:
            self.current_index += 1
            self.update_ui()

    def generate_audio(self):
        """Generate audio for the current item using ElevenLabs API"""
        if self.generate_btn.cget('state') == tk.DISABLED:
            return

        if not self.elevenlabs_api_key:
            self.show_elevenlabs_settings()
            return

        if self.current_index < len(self.filenames):
            filename = self.filenames[self.current_index]
            phrase = self.phrases[self.current_index]

            # Remove the line number prefix
            if '. ' in phrase:
                phrase = phrase.split('. ', 1)[1]

            output_path = os.path.join(self.output_dir, filename)

            # Disable UI during generation
            self.disable_ui_during_operation()
            self.status_var.set(f"Generating audio for {filename}...")

            # Generate in a separate thread
            threading.Thread(
                target=self.generate_audio_thread,
                args=(phrase, output_path, self.current_index),
                daemon=True
            ).start()

    def generate_audio_thread(self, text, output_path, index):
        """Thread function for generating audio with ElevenLabs"""
        try:
            success = self.text_to_speech_file(text, output_path)

            if success:
                self.recorded[index] = True

                # Trim the generated audio
                # self.trim_wav(output_path)

                self.root.after(0, lambda: self.status_var.set(f"Generated audio for {os.path.basename(output_path)}"))
            else:
                self.root.after(0, lambda: self.status_var.set("Failed to generate audio"))

        except Exception as e:
            self.root.after(0, lambda: self.status_var.set(f"Error generating audio: {e}"))

        finally:
            # Re-enable UI
            self.root.after(0, self.enable_ui_after_operation)

    def generate_all_missing(self):
        """Generate audio for all missing items"""
        if self.generate_all_btn.cget('state') == tk.DISABLED:
            return

        if not self.elevenlabs_api_key:
            self.show_elevenlabs_settings()
            return

        missing_indices = [i for i, recorded in enumerate(self.recorded) if not recorded]

        if not missing_indices:
            messagebox.showinfo("Info", "No missing files to generate")
            return

        # Confirm with user
        if not messagebox.askyesno("Confirm", f"Generate audio for {len(missing_indices)} missing items?"):
            return

        # Disable UI during generation
        self.disable_ui_during_operation()

        # Start generation in a separate thread
        threading.Thread(
            target=self.generate_all_missing_thread,
            args=(missing_indices,),
            daemon=True
        ).start()

    def generate_all_missing_thread(self, indices):
        """Thread function for generating all missing audio files"""
        total = len(indices)
        success_count = 0

        for i, idx in enumerate(indices):
            filename = self.filenames[idx]
            phrase = self.phrases[idx]

            # Remove the line number prefix
            if '. ' in phrase:
                phrase = phrase.split('. ', 1)[1]

            output_path = os.path.join(self.output_dir, filename)

            self.root.after(0, lambda: self.status_var.set(f"Generating {i+1}/{total}: {filename}..."))

            try:
                success = self.text_to_speech_file(phrase, output_path)

                if success:
                    self.recorded[idx] = True
                    success_count += 1

                    # Trim the generated audio
                    # self.trim_wav(output_path)

                # Small delay to avoid rate limiting
                time.sleep(0.5)

            except Exception as e:
                self.root.after(0, lambda: self.status_var.set(f"Error generating {filename}: {e}"))

        self.root.after(0, lambda: self.status_var.set(f"Generated {success_count}/{total} audio files"))
        self.root.after(0, self.enable_ui_after_operation)

    def text_to_speech_file(self, text, output_path):
        """Generate speech from text using ElevenLabs API and save to file"""
        URL = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}?output_format=pcm_{PCM_SAMPLE_RATE}"

        headers = {
            "xi-api-key": self.elevenlabs_api_key,
            "Content-Type": "application/json"
        }

        data = {
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": {
                "speed": 0.95,
                "stability": 1,
                "similarity_boost": 1,
                "style": 1,
                "use_speaker_boost": True
            }
        }

        try:
            response = requests.post(URL, json=data, headers=headers)
            response.raise_for_status()

            # The response is raw PCM data, we need to convert it to WAV
            pcm_data = response.content

            # Create a WAV file with the PCM data
            with wave.open(output_path, 'wb') as wf:
                wf.setnchannels(1)  # Mono
                wf.setsampwidth(2)  # 16-bit
                wf.setframerate(PCM_SAMPLE_RATE)  # 22050 Hz
                wf.writeframes(pcm_data)

            print(f'Generated {output_path} successfully.')
            return True

        except requests.exceptions.RequestException as e:
            print(f"Error generating audio: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Error saving audio: {e}", file=sys.stderr)
            return False

    def disable_ui_during_operation(self):
        """Disable UI elements during long operations"""
        self.record_btn.config(state=tk.DISABLED)
        self.play_btn.config(state=tk.DISABLED)
        self.prev_btn.config(state=tk.DISABLED)
        self.next_btn.config(state=tk.DISABLED)
        self.generate_btn.config(state=tk.DISABLED)
        self.generate_all_btn.config(state=tk.DISABLED)

    def enable_ui_after_operation(self):
        """Re-enable UI elements after operations complete"""
        self.update_ui()

    def show_room_tone_dialog(self):
        """Show dialog for room tone removal"""
        dialog = tk.Toplevel(self.root)
        dialog.title("Remove Room Tone")
        dialog.geometry("500x300")
        dialog.transient(self.root)
        dialog.grab_set()

        ttk.Label(dialog, text="Remove background noise from recordings",
                 font=('TkDefaultFont', 12, 'bold')).pack(pady=(10, 20))

        # Input directory
        input_frame = ttk.Frame(dialog)
        input_frame.pack(fill=tk.X, padx=20, pady=5)

        ttk.Label(input_frame, text="Input Directory:").pack(side=tk.LEFT)
        input_var = tk.StringVar(value=self.output_dir)
        input_entry = ttk.Entry(input_frame, textvariable=input_var, width=30)
        input_entry.pack(side=tk.LEFT, padx=(5, 5), fill=tk.X, expand=True)

        ttk.Button(input_frame, text="Browse",
                  command=lambda: input_var.set(filedialog.askdirectory(initialdir=input_var.get()))).pack(side=tk.LEFT)

        # Output directory
        output_frame = ttk.Frame(dialog)
        output_frame.pack(fill=tk.X, padx=20, pady=5)

        ttk.Label(output_frame, text="Output Directory:").pack(side=tk.LEFT)
        output_var = tk.StringVar(value=os.path.join(self.output_dir, "noise_removed"))
        output_entry = ttk.Entry(output_frame, textvariable=output_var, width=30)
        output_entry.pack(side=tk.LEFT, padx=(5, 5), fill=tk.X, expand=True)

        ttk.Button(output_frame, text="Browse",
                  command=lambda: output_var.set(filedialog.askdirectory(initialdir=output_var.get()))).pack(side=tk.LEFT)

        # Room tone file
        roomtone_frame = ttk.Frame(dialog)
        roomtone_frame.pack(fill=tk.X, padx=20, pady=5)

        ttk.Label(roomtone_frame, text="Room Tone File:").pack(side=tk.LEFT)
        roomtone_var = tk.StringVar(value=os.path.join(self.output_dir, "roomtone.wav"))
        roomtone_entry = ttk.Entry(roomtone_frame, textvariable=roomtone_var, width=30)
        roomtone_entry.pack(side=tk.LEFT, padx=(5, 5), fill=tk.X, expand=True)

        ttk.Button(roomtone_frame, text="Browse",
                  command=lambda: roomtone_var.set(filedialog.askopenfilename(
                      initialdir=os.path.dirname(roomtone_var.get()),
                      filetypes=[("WAV files", "*.wav")]))).pack(side=tk.LEFT)

        # Record room tone button
        ttk.Button(dialog, text="Record Room Tone (10 seconds)",
                  command=lambda: self.record_room_tone(roomtone_var.get())).pack(pady=(10, 0))

        # Process button
        ttk.Button(dialog, text="Process",
                  command=lambda: self.process_room_tone_removal(
                      input_var.get(), output_var.get(), roomtone_var.get(), dialog)).pack(pady=(20, 10))

    def record_room_tone(self, output_path):
        """Record room tone for noise removal"""
        # Ensure directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        try:
            # Record 10 seconds of audio
            subprocess.run(
                ['arecord', '-f', 'cd', '-t', 'wav', '-d', '10', '-r', '44100', output_path],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            messagebox.showinfo("Success", f"Room tone recorded to {output_path}")

        except Exception as e:
            messagebox.showerror("Error", f"Failed to record room tone: {e}")

    def process_room_tone_removal(self, input_dir, output_dir, roomtone_file, dialog):
        """Process room tone removal using sox"""
        if not os.path.exists(input_dir):
            messagebox.showerror("Error", f"Input directory {input_dir} does not exist")
            return

        if not os.path.exists(roomtone_file):
            messagebox.showerror("Error", f"Room tone file {roomtone_file} does not exist")
            return

        # Create output directory
        os.makedirs(output_dir, exist_ok=True)

        # Close the dialog
        dialog.destroy()

        # Disable UI during processing
        self.disable_ui_during_operation()
        self.status_var.set("Processing room tone removal...")

        # Run in a separate thread
        threading.Thread(
            target=self.run_room_tone_removal,
            args=(input_dir, output_dir, roomtone_file),
            daemon=True
        ).start()

    def run_room_tone_removal(self, input_dir, output_dir, roomtone_file):
        """Run room tone removal in a separate thread"""
        try:
            # Create noise profile
            noise_profile = os.path.join(tempfile.gettempdir(), "noise.prof")

            subprocess.run(
                ['sox', roomtone_file, '-n', 'noiseprof', noise_profile],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )

            # Process each WAV file
            wav_files = [f for f in os.listdir(input_dir) if f.endswith('.wav')]
            total_files = len(wav_files)

            for i, wav_file in enumerate(wav_files):
                input_path = os.path.join(input_dir, wav_file)
                output_path = os.path.join(output_dir, wav_file)

                self.root.after(0, lambda: self.status_var.set(f"Processing {i+1}/{total_files}: {wav_file}"))

                subprocess.run(
                    ['sox', input_path, output_path, 'noisered', noise_profile, '0.21'],
                    check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )

            self.root.after(0, lambda: messagebox.showinfo(
                "Success", f"Processed {total_files} files. Cleaned files are in {output_dir}"))

        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", f"Room tone removal failed: {e}"))

        finally:
            # Re-enable UI
            self.root.after(0, self.enable_ui_after_operation)

    def show_elevenlabs_settings(self):
        """Show dialog for ElevenLabs API settings"""
        dialog = tk.Toplevel(self.root)
        dialog.title("ElevenLabs Settings")
        dialog.geometry("500x200")
        dialog.transient(self.root)
        dialog.grab_set()

        ttk.Label(dialog, text="ElevenLabs API Settings",
                 font=('TkDefaultFont', 12, 'bold')).pack(pady=(10, 20))

        # API Key
        key_frame = ttk.Frame(dialog)
        key_frame.pack(fill=tk.X, padx=20, pady=5)

        ttk.Label(key_frame, text="API Key:").pack(side=tk.LEFT)
        key_var = tk.StringVar(value=self.elevenlabs_api_key)
        key_entry = ttk.Entry(key_frame, textvariable=key_var, width=40, show="*")
        key_entry.pack(side=tk.LEFT, padx=(5, 0), fill=tk.X, expand=True)

        # Show/hide password
        show_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(key_frame, text="Show", variable=show_var,
                       command=lambda: key_entry.config(show="" if show_var.get() else "*")).pack(side=tk.LEFT, padx=(5, 0))

        # Save button
        ttk.Button(dialog, text="Save",
                  command=lambda: self.save_elevenlabs_settings(key_var.get(), dialog)).pack(pady=(20, 10))

    def save_elevenlabs_settings(self, api_key, dialog):
        """Save ElevenLabs API settings"""
        self.elevenlabs_api_key = api_key

        # Save to .env file
        try:
            env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")

            # Read existing .env file if it exists
            env_vars = {}
            if os.path.exists(env_path):
                with open(env_path, 'r') as f:
                    for line in f:
                        if '=' in line:
                            key, value = line.strip().split('=', 1)
                            env_vars[key] = value

            # Update API key
            env_vars["ELEVENLABS_API_KEY"] = api_key

            # Write back to .env file
            with open(env_path, 'w') as f:
                for key, value in env_vars.items():
                    f.write(f"{key}={value}\n")

            messagebox.showinfo("Success", "API key saved successfully")
            dialog.destroy()

            # Update UI to enable/disable generate buttons
            self.update_ui()

        except Exception as e:
            messagebox.showerror("Error", f"Failed to save API key: {e}")

    def show_about(self):
        """Show about dialog"""
        about_text = """
TextyMcSpeechy Dataset Recorder

A graphical tool for recording and generating datasets for text-to-speech models.
Combines functionality from dataset_recorder.sh, new_dataset_recorder.sh, and geteleven.py.

Features:
- Record audio for each phrase in a CSV file
- Generate audio using ElevenLabs API
- Remove background noise from recordings
- Trim silence from recordings
- Visualize audio waveforms

For more information, visit the documentation.
"""
        messagebox.showinfo("About", about_text)

    def on_closing(self):
        """Handle window closing"""
        # Stop any ongoing playback
        self.stop_playback()

        # Clean up audio resources
        if self.p:
            self.p.terminate()

        self.root.destroy()

def main():
    root = tk.Tk()
    app = DatasetRecorder(root)
    root.mainloop()

if __name__ == "__main__":
    main()
