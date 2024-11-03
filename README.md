# Stereo Field Angle Audio Processor

This project is a Processing-based application for analyzing and manipulating stereo audio files using Fourier-based processing. The program visualizes the stereo field angle of audio data, applies selective gain changes based on panning, and supports FFT-based resynthesis with overlap-add techniques.

## Features

- **Load Stereo WAV Files**: Drag and drop WAV files to analyze their stereo field.
- **Fourier-Based Processing**: Computes FFT on stereo channels with a customizable overlap and windowing function (Hann).
- **Panning-Based Manipulation**: Allows selective adjustment (amplify, attenuate, mute) of audio frequencies within specific panning and time ranges.
- **Real-Time Visual Feedback**:
  - **Panning Display**: Visualizes panning intensity and amplitude in the stereo field over time.
  - **Spectrogram Display**: Renders separate left and right channel spectrograms.
- **Resynthesis and Export**: Performs inverse FFT to reconstruct the audio and exports it as a processed WAV file.

## How to Use

1. **Load a File**: Drag and drop a `.wav` file onto the window to load it.
2. **Select a Zone**: 
   - Click and drag to define a time and panning range.  
   - **Y-axis**: Maps panning from -1 (left) to 1 (right).
   - **X-axis**: Maps time within the file's duration.
3. **Apply Adjustments**:
   - `+` Key: Amplifies selected zone.
   - `-` Key: Attenuates selected zone.
   - `Delete` Key: Mutes the selected zone.
4. **Resynthesize and Export**:
   - Press `Enter` to process the audio with current settings and export the result as a new WAV file.

## Controls

- **File Handling**:
  - *Drag & Drop*: Load a WAV file.
  - *Enter*: Resynthesize and export the processed audio.
- **Selection Controls**:
  - *Mouse Click and Drag*: Define a panning and time range.
- **Processing Controls**:
  - `+`: Increase gain in selected zone.
  - `-`: Decrease gain in selected zone.
  - `Delete`: Mute the selected zone.

## Installation

### Requirements

- **Processing IDE**: Install [Processing](https://processing.org/download/) for running the sketch.
- **Minim Library**: Ensure the Minim library is installed in Processing.
  - Go to *Sketch -> Import Library -> Add Library...* and search for "Minim".
- **SDrop Library**: Required for drag-and-drop functionality.
  - Go to *Sketch -> Import Library -> Add Library...* and search for "Drop".

### Running the Sketch

1. Open `stereoExtractor.pde` in Processing.
2. Ensure all associated `.pde` files (e.g., `sampleSlot.pde`) are in the same sketch folder.
3. Run the sketch from the Processing IDE.

## Code Overview

- **Main Processing Loop** (`draw()`): Handles real-time user interaction and visualization.
- **Sample Class**: Manages audio file loading, FFT analysis, panning manipulation, and resynthesis.
  - `computeFullFFT()`: Performs FFT on audio data with overlap and Hann windowing.
  - `displayPanning()`: Visualizes stereo panning intensity.
  - `multiplyPanningRange()`: Adjusts amplitudes in a user-defined panning and time range.
  - `resynthesize()`: Reconstructs audio from manipulated spectrogram data.

## Notes

- **Overlap and Windowing**: Uses 75% overlap with Hann windowing for smoother transitions in FFT processing and synthesis.
- **Exported Files**: Processed audio is saved with a unique name based on the original filename to prevent overwriting.
