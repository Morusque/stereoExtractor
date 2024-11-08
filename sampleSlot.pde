
class Sample {
  String url = "";
  int nbChannels;
  double[][] nSample;
  double[][] nSampleProcessed;
  float maxSampleValue;
  int audioDataLength;
  boolean isBigEndian;
  int bytePerSample;
  AudioFormat format;
  Minim minim;
  FFT fftL, fftR;
  float[][] leftChannelSpectrogram;
  float[][] rightChannelSpectrogram;
  float[][] leftChannelPhase;
  float[][] rightChannelPhase;
  int fftSize = 1024;
  float maxAmplitude = 1.0;
  int numFrames;
  int hopSize = fftSize / 8;
  float epsilon = 1e-6; // Small value to prevent division by zero

  Sample(File file) {
    this.url = file.getPath();
    minim = new Minim(this);
    loadFile();
  }

  void loadFile() {
    try {
      AudioInputStream ais = AudioSystem.getAudioInputStream(new File(url));
      format = ais.getFormat();
      int frameLength = (int)ais.getFrameLength();
      byte[] audioData = new byte[frameLength * format.getFrameSize()];
      audioDataLength = audioData.length;
      ais.read(audioData);

      nbChannels = format.getChannels();
      int sampleSizeInBits = format.getSampleSizeInBits();
      isBigEndian = format.isBigEndian();
      bytePerSample = 1;

      if (sampleSizeInBits == 8) {
        maxSampleValue = 127f;
        bytePerSample = 1;
      } else if (sampleSizeInBits == 16) {
        maxSampleValue = 32767f;
        bytePerSample = 2;
      } else if (sampleSizeInBits == 24) {
        maxSampleValue = 8388607f;
        bytePerSample = 3;
      } else {
        throw new IllegalArgumentException("Unsupported bit depth: " + sampleSizeInBits);
      }

      nSample = new double[nbChannels][audioData.length / (bytePerSample * nbChannels)];
      for (int i = 0; i < audioData.length; i += bytePerSample * nbChannels) {
        for (int c = 0; c < nbChannels; c++) {
          int offset = i + c * bytePerSample;
          double sampleValue = 0.0;
          if (bytePerSample == 1) {
            sampleValue = (double)audioData[offset] / maxSampleValue;
          } else if (bytePerSample == 2) {
            short sample = ByteBuffer.wrap(audioData, offset, 2)
              .order(isBigEndian ? ByteOrder.BIG_ENDIAN : ByteOrder.LITTLE_ENDIAN)
              .getShort();
            sampleValue = (double)sample / maxSampleValue;
          } else if (bytePerSample == 3) {
            // For 24-bit, convert manually
            int sample = (audioData[offset] & 0xFF) << 16 | (audioData[offset + 1] & 0xFF) << 8 | (audioData[offset + 2] & 0xFF);
            sample = sample << 8 >> 8; // Sign extend
            sampleValue = (double)sample / maxSampleValue;
          }
          nSample[c][i / (bytePerSample * nbChannels)] = sampleValue;
        }
      }
      nSampleProcessed = deepCopy(nSample);
    }
    catch (Exception e) {
      e.printStackTrace();
    }
  }

  void exportSample() {
    try {
      // Convert double samples back into byte data
      byte[] byteData = new byte[audioDataLength];
      for (int c = 0; c < nbChannels; c++) {
        for (int i = 0; i < nSampleProcessed[c].length; i++) {
          int sampleAsInt = (int)(nSampleProcessed[c][i] * maxSampleValue);

          byte[] sampleBytes;
          switch (bytePerSample) {
          case 1:
            sampleBytes = new byte[] {(byte) sampleAsInt};
            break;
          case 2:
            sampleBytes = ByteBuffer.allocate(2).order(isBigEndian?ByteOrder.BIG_ENDIAN:ByteOrder.LITTLE_ENDIAN).putShort((short) sampleAsInt).array();
            break;
          case 3:
            sampleBytes = new byte[3];
            sampleBytes[0] = (byte) (sampleAsInt & 0xFF);
            sampleBytes[1] = (byte) ((sampleAsInt >> 8) & 0xFF);
            sampleBytes[2] = (byte) ((sampleAsInt >> 16) & 0xFF);
            break;
          default:
            throw new IllegalArgumentException("Unsupported byte depth: " + bytePerSample);
          }

          System.arraycopy(sampleBytes, 0, byteData, i*bytePerSample*nbChannels + c*bytePerSample, bytePerSample);
        }
      }

      // Create a new AudioInputStream from the byte data
      ByteArrayInputStream bais = new ByteArrayInputStream(byteData);
      AudioInputStream outputAis = new AudioInputStream(bais, format, audioDataLength / format.getFrameSize());

      // Write the AudioInputStream to a file
      String exportUrl = url;
      int lastDot = 0;
      for (int i=exportUrl.length()-1; i>=0; i--) {
        if (exportUrl.charAt(i)=='.') {
          lastDot = i;
          break;
        }
      }
      String baseExportUrl = exportUrl.substring(0, lastDot)+"_processed";
      int incrementName = 0;
      exportUrl = baseExportUrl+"_"+nf(incrementName++, 2)+".wav";
      while ((new File(exportUrl)).exists()) exportUrl = baseExportUrl+"_"+nf(incrementName++, 2)+".wav";
      AudioSystem.write(outputAis, AudioFileFormat.Type.WAVE, new File(exportUrl));
    }
    catch(Exception e) {
      println(e);
    }
  }

  void computeFullFFT() {
    numFrames = (nSample[0].length - fftSize) / hopSize + 1;

    leftChannelSpectrogram = new float[numFrames][fftSize / 2];
    rightChannelSpectrogram = new float[numFrames][fftSize / 2];
    leftChannelPhase = new float[numFrames][fftSize / 2];
    rightChannelPhase = new float[numFrames][fftSize / 2];

    fftL = new FFT(fftSize, 44100);
    fftR = new FFT(fftSize, 44100);

    // Define a Hann window
    float[] window = new float[fftSize];
    for (int i = 0; i < fftSize; i++) {
      window[i] = pow( sin( PI * i / fftSize ), 2 );
    }

    for (int frame = 0; frame < numFrames; frame++) {
      float[] leftBuffer = new float[fftSize];
      float[] rightBuffer = new float[fftSize];
      int startIdx = frame * hopSize;

      // Apply windowing for analysis
      for (int i = 0; i < fftSize; i++) {
        int sampleIndex = startIdx + i;
        if (sampleIndex < nSample[0].length) { // Check bounds
          leftBuffer[i] = (float) nSample[0][sampleIndex] * window[i];
          rightBuffer[i] = (float) nSample[1][sampleIndex] * window[i];
        }
      }

      // Perform FFT
      fftL.forward(leftBuffer);
      fftR.forward(rightBuffer);

      // Store magnitude and phase
      for (int i = 0; i < fftSize / 2; i++) {
        float realL = fftL.getSpectrumReal()[i];
        float imagL = fftL.getSpectrumImaginary()[i];
        float realR = fftR.getSpectrumReal()[i];
        float imagR = fftR.getSpectrumImaginary()[i];

        // Calculate magnitude and phase
        leftChannelSpectrogram[frame][i] = sqrt(realL * realL + imagL * imagL);
        rightChannelSpectrogram[frame][i] = sqrt(realR * realR + imagR * imagR);
        leftChannelPhase[frame][i] = atan2(imagL, realL);
        rightChannelPhase[frame][i] = atan2(imagR, realR);
      }
    }
  }

  void drawSpectrogram() {
    background(0);

    int halfWidth = width / 2;
    float frameWidth = (float) halfWidth / numFrames;
    float binHeight = (float) height / (fftSize / 2);

    rectMode(CORNER);

    // Draw left channel spectrogram
    for (int frame = 0; frame < numFrames; frame++) {
      for (int bin = 0; bin < fftSize / 2; bin++) {
        float amplitude = leftChannelSpectrogram[frame][bin];
        float brightness = map(amplitude, 0, 1.0, 0, 255);
        fill(brightness);
        noStroke();
        rect(frame * frameWidth, height - bin * binHeight, frameWidth, binHeight);
      }
    }

    // Draw right channel spectrogram
    for (int frame = 0; frame < numFrames; frame++) {
      for (int bin = 0; bin < fftSize / 2; bin++) {
        float amplitude = rightChannelSpectrogram[frame][bin];
        float brightness = map(amplitude, 0, 1.0, 0, 255);
        fill(brightness);
        noStroke();
        rect(halfWidth + frame * frameWidth, height - bin * binHeight, frameWidth, binHeight);
      }
    }
  }

  void displayPanning() {
    float frameWidth = (float) width / numFrames;
    float binHeight = (float) height / (fftSize / 2);

    rectMode(CORNER);

    for (int frame = 0; frame < numFrames; frame++) {
      for (int bin = 0; bin < fftSize / 2; bin++) {
        float leftAmplitude = leftChannelSpectrogram[frame][bin];
        float rightAmplitude = rightChannelSpectrogram[frame][bin];

        // Avoid division by zero with epsilon
        float totalAmplitude = rightAmplitude + leftAmplitude;

        float panning = (rightAmplitude - leftAmplitude) / totalAmplitude;
        float avgAmp = totalAmplitude / 2;

        if (abs(totalAmplitude) < epsilon) panning=0; // Skip if near zero

        float x = frame * frameWidth;
        float y = map(panning, -1.0, 1.0, 0, height);

        fill(HSBtoRGB(map(bin, 0, fftSize / 2, 0, 0xE0), 0xFF, logBrightness(avgAmp)));

        noStroke();
        rect(x, y, frameWidth, binHeight);
      }
    }
  }

  void multiplyPanningRange(float from, float to, float timeA, float timeB, float multiplier) {

    if (from>to) {
      float temp = to;
      to = from;
      from = temp;
    }
    if (timeA>timeB) {
      float temp = timeB;
      timeB = timeA;
      timeA = temp;
    }

    for (int frame = floor(timeA*leftChannelSpectrogram.length); frame < floor(timeB*leftChannelSpectrogram.length); frame++) {
      for (int bin = 0; bin < leftChannelSpectrogram[frame].length; bin++) {

        // Get amplitude for left and right channels
        float leftAmp = leftChannelSpectrogram[frame][bin];
        float rightAmp = rightChannelSpectrogram[frame][bin];
        float totalAmp = leftAmp + rightAmp;

        // Calculate panning between -1 (left) and 1 (right), with epsilon to prevent division by zero
        float panning = (rightAmp - leftAmp) / (totalAmp + epsilon);

        // Check if panning is within the specified range and if panning is a valid number
        if (!Float.isNaN(panning) && panning >= from && panning <= to) {
          // Apply the multiplier to both channels in the specified range
          leftChannelSpectrogram[frame][bin] *= multiplier;
          rightChannelSpectrogram[frame][bin] *= multiplier;
        }
      }
    }
  }

  void shiftPanningRange(float from, float to, float timeA, float timeB, float shiftAmount) {

    if (from>to) {
      float temp = to;
      to = from;
      from = temp;
    }
    if (timeA>timeB) {
      float temp = timeB;
      timeB = timeA;
      timeA = temp;
    }

    for (int frame = floor(timeA * leftChannelSpectrogram.length); frame < floor(timeB * leftChannelSpectrogram.length); frame++) {
      for (int bin = 0; bin < leftChannelSpectrogram[frame].length; bin++) {
        float leftAmp = leftChannelSpectrogram[frame][bin];
        float rightAmp = rightChannelSpectrogram[frame][bin];
        float totalAmp = leftAmp + rightAmp;

        float panning = (rightAmp - leftAmp) / (totalAmp + epsilon);

        if (!Float.isNaN(panning) && panning >= from && panning <= to) {
          // Calculate new panning by shifting
          leftChannelSpectrogram[frame][bin] = max(0, leftAmp - shiftAmount);
          rightChannelSpectrogram[frame][bin] = max(0, rightAmp + shiftAmount);
        }
      }
    }
  }

  void invertPanningRange(float from, float to, float timeA, float timeB) {

    if (from>to) {
      float temp = to;
      to = from;
      from = temp;
    }
    if (timeA>timeB) {
      float temp = timeB;
      timeB = timeA;
      timeA = temp;
    }

    float midpoint = (from + to) / 2;

    for (int frame = floor(timeA * leftChannelSpectrogram.length); frame < floor(timeB * leftChannelSpectrogram.length); frame++) {
      for (int bin = 0; bin < leftChannelSpectrogram[frame].length; bin++) {
        float leftAmp = leftChannelSpectrogram[frame][bin];
        float rightAmp = rightChannelSpectrogram[frame][bin];
        float totalAmp = leftAmp + rightAmp;

        float panning = (rightAmp - leftAmp) / (totalAmp + epsilon);

        if (!Float.isNaN(panning) && panning >= from && panning <= to) {
          // Calculate new panning based on inversion around the midpoint
          float invertedPanning = midpoint - (panning - midpoint);
          // Calculate new left and right amplitudes based on inverted panning
          leftChannelSpectrogram[frame][bin] = totalAmp * (1 - (invertedPanning + 1) / 2);
          rightChannelSpectrogram[frame][bin] = totalAmp * ((invertedPanning + 1) / 2);
        }
      }
    }
  }

  void resynthesize() {
    int totalLength = (numFrames - 1) * hopSize + fftSize;
    nSampleProcessed = new double[2][totalLength];
    double[] normalization = new double[totalLength]; // To track overlaps

    float[] freqRealL = new float[fftSize];
    float[] freqImagL = new float[fftSize];
    float[] bufferL = new float[fftSize];

    float[] freqRealR = new float[fftSize];
    float[] freqImagR = new float[fftSize];
    float[] bufferR = new float[fftSize];

    // Define a Hann window for synthesis
    float[] window = new float[fftSize];
    for (int i = 0; i < fftSize; i++) {
      window[i] = pow( sin( PI * i / fftSize ), 2 );
    }

    for (int frame = 0; frame < numFrames; frame++) {
      // Populate real and imaginary components from magnitude and phase
      for (int i = 0; i < fftSize / 2; i++) {
        float magnitudeL = leftChannelSpectrogram[frame][i];
        float phaseL = leftChannelPhase[frame][i];
        freqRealL[i] = magnitudeL * cos(phaseL);
        freqImagL[i] = magnitudeL * sin(phaseL);

        float magnitudeR = rightChannelSpectrogram[frame][i];
        float phaseR = rightChannelPhase[frame][i];
        freqRealR[i] = magnitudeR * cos(phaseR);
        freqImagR[i] = magnitudeR * sin(phaseR);
      }

      fftL.inverse(freqRealL, freqImagL, bufferL);
      fftR.inverse(freqRealR, freqImagR, bufferR);

      float increaseGainBy = 2.0;// I'm really not sure why I have to do this

      // Overlap-add with windowing
      int startIdx = frame * hopSize;
      for (int i = 0; i < fftSize; i++) {
        int pos = startIdx + i;
        if (pos < nSampleProcessed[0].length) {
          nSampleProcessed[0][pos] += bufferL[i] * window[i] * increaseGainBy;
          nSampleProcessed[1][pos] += bufferR[i] * window[i] * increaseGainBy;
          normalization[pos] += window[i]; // Track contributions
        }
      }
    }

    // Normalize the overlapped output
    for (int i = 0; i < nSampleProcessed[0].length; i++) {
      if (normalization[i] > 0) { // Avoid division by zero
        nSampleProcessed[0][i] /= normalization[i];
        nSampleProcessed[1][i] /= normalization[i];
      }
    }
  }

  // Simple inverse FFT implementation
  void inverseFFT(double[] complexData) {
    int n = complexData.length / 2;
    for (int k = 0; k < n; k++) {
      double sumReal = 0;
      double sumImag = 0;
      for (int i = 0; i < n; i++) {
        float angle = 2 * PI * i * k / n;
        sumReal += complexData[2 * i] * cos(angle) - complexData[2 * i + 1] * sin(angle);
        sumImag += complexData[2 * i] * sin(angle) + complexData[2 * i + 1] * cos(angle);
      }
      complexData[2 * k] = sumReal / n; // Normalize real part
      complexData[2 * k + 1] = sumImag / n; // Normalize imaginary part
    }
  }
}

double[][] deepCopy(double[][] original) {
  if (original == null) {
    return null;
  }

  double[][] copy = new double[original.length][];
  for (int i = 0; i < original.length; i++) {
    copy[i] = new double[original[i].length];
    System.arraycopy(original[i], 0, copy[i], 0, original[i].length);
  }
  return copy;
}

int logBrightness(float avgAmp) {
  float minAmp = 0.00001;
  float maxAmp = 1.0;
  avgAmp = max(minAmp, avgAmp);
  float normalizedLogAmp = (log(avgAmp) - log(minAmp)) / (log(maxAmp) - log(minAmp));
  return (int)(normalizedLogAmp * 255);
}
