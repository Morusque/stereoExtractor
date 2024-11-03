
import drop.*;

import java.io.*;
import javax.sound.sampled.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Random;

import ddf.minim.*;
import ddf.minim.analysis.*;

import java.lang.reflect.Array;

Sample sample;

SDrop drop;

void setup() {
  size(1400, 500);
  drop = new SDrop(this);
  frameRate(20);
}

void draw() {
  // update
  if (mousePressed) {
    float constrainedY = constrain((float)mouseY, 0, height);
    lowerPannnigBound = map(constrainedY / height, 0, 1, -1, 1);
    float constrainedX = constrain((float)mouseX, 0, width);
    timeBBound = constrainedX/width;
  }
  // draw
  background(0);
  if (sample!=null) sample.displayPanning();
  stroke(0xFF, 0xA0);
  line(0, height/2, width, height/2);
  if (lowerPannnigBound != upperPannnigBound) {
    rectMode(CORNERS);
    noStroke();
    fill(0x80, 0xB0, 0xF0, 0x50);
    rect(timeABound*width, map(upperPannnigBound, -1, 1, 0, height), timeBBound*width, map(lowerPannnigBound, -1, 1, 0, height));
  }
  fill(0xFF);
  textSize(15);
  text("drop wav : load file", 20, 20);
  text("click+drag : define zone", 20, 40);
  text("del : delete", 20, 60);
  text("+ : more gain", 20, 80);
  text("- : less gain", 20, 100);
  text("enter : export", 20, 120);
}

color HSBtoRGB(float h, float s, float b) {
  int rgb = color(0); // Default to black
  // Use Processing's built-in colorMode to handle conversion
  colorMode(HSB); // HSB values range from 0 to 1
  rgb = color(h, s, b); // Create color in HSB
  colorMode(RGB); // Switch back to RGB mode with range 0 to 255
  return rgb;
}

float upperPannnigBound = 0;
float lowerPannnigBound = 0;
float timeABound = 0;
float timeBBound = 0;

void mousePressed() {
  float constrainedY = constrain((float)mouseY, 0, height);
  upperPannnigBound = map(constrainedY/height, 0, 1, -1, 1);
  float constrainedX = constrain((float)mouseX, 0, width);
  timeABound = constrainedX/width;
}

void mouseReleased() {
}

void keyPressed() {
  if (keyCode == 127) {// suppr
    sample.multiplyPanningRange(upperPannnigBound, lowerPannnigBound, timeABound, timeBBound, 0);
  }
  if (key == '+') {
    sample.multiplyPanningRange(upperPannnigBound, lowerPannnigBound, timeABound, timeBBound, 1.1);
  }
  if (key == '-') {
    sample.multiplyPanningRange(upperPannnigBound, lowerPannnigBound, timeABound, timeBBound, 0.9);
  }
  if (key == ENTER) {
    sample.resynthesize();
    sample.exportSample();
  }
}

void dropEvent(DropEvent theDropEvent) {
  if (theDropEvent.isFile()) {
    File theFile = theDropEvent.file();
    if (!theFile.isDirectory()) {
      try {
        sample = new Sample(theFile.getAbsoluteFile());
        sample.computeFullFFT();
      }
      catch(Exception e) {
        println(e);
      }
    }
  }
}
