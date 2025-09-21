#ifndef RAINSENSOR_H
#define RAINSENSOR_H

#define RAIN_DO_PIN 22  
#define RAIN_AO_PIN 19  

unsigned long rainStartTime = 0;
bool rainDetectedState = false;


int ANALOG_NONE = 0;   // dry
const int ANALOG_LIGHT_OFFSET  = 800;   
const int ANALOG_MEDIUM_OFFSET = 1800;
const int ANALOG_HEAVY_OFFSET  = 2800;


inline void initRainSensor() {
    pinMode(RAIN_DO_PIN, INPUT);
    pinMode(RAIN_AO_PIN, INPUT);

    
    long sum = 0;
    for (int i = 0; i < 50; i++) {
        sum += analogRead(RAIN_AO_PIN);
        delay(20);
    }
    ANALOG_NONE = sum / 50;
}

// Read analog value
inline int readRainValue() {
    return analogRead(RAIN_AO_PIN);
}


inline String getRainIntensity() {
    int val = readRainValue();
    if (val >= ANALOG_NONE) return "NONE";
    else if (val >= ANALOG_NONE - ANALOG_LIGHT_OFFSET) return "LIGHT";
    else if (val >= ANALOG_NONE - ANALOG_MEDIUM_OFFSET) return "MEDIUM";
    else return "HEAVY";
}

// Check if rain is detected
inline bool checkRainDetected() {
    bool digitalRain = digitalRead(RAIN_DO_PIN) == LOW;

    
    bool currentRain = digitalRain || (analogVal < (ANALOG_NONE - ANALOG_LIGHT_OFFSET));

    // Debounce for 7 seconds
    if (currentRain) {
        if (!rainDetectedState) {
            rainStartTime = millis();
            rainDetectedState = true;
            return false;  
            if (millis() - rainStartTime >= 7000) {
                return true;  
            } else {
                return false;
            }
        }
    } else {
        rainDetectedState = false;  
        return false;
    }
}

#endif
