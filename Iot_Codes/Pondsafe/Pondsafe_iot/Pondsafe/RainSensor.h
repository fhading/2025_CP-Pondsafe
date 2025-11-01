#ifndef RAINSENSOR_H
#define RAINSENSOR_H

#include <Arduino.h>

#define RAIN_AO_PIN 35

unsigned long rainStartTime = 0;
bool rainDetectedState = false;
const unsigned long RAIN_DELAY_MS = 6000;

void initRainSensor() {
    pinMode(RAIN_AO_PIN, INPUT);
    rainStartTime = 0;
    rainDetectedState = false;
}

// Optional: read raw sensor value
int readRainValue() {
    return analogRead(RAIN_AO_PIN);
}

// Returns "No Rain", "Light", "Moderate", or "Heavy"
String readRainIntensity() {
    int ao = analogRead(RAIN_AO_PIN); 
    if (ao > 3500) return "No Rain";
    else if (ao > 3000) return "Light";
    else if (ao > 2500) return "Moderate";
    else return "Heavy";
}

// Returns true if rain detected for longer than RAIN_DELAY_MS
bool checkRainDetected() {
    int ao = analogRead(RAIN_AO_PIN);
    bool currentRain = (ao <= 3500); 
    if (currentRain) {
        if (rainStartTime == 0) rainStartTime = millis();
        if ((millis() - rainStartTime) >= RAIN_DELAY_MS) {
            rainDetectedState = true;
            return true;
        }
        return false;
    } else {
        rainStartTime = 0;
        rainDetectedState = false;
        return false;
    }
}

#endif
