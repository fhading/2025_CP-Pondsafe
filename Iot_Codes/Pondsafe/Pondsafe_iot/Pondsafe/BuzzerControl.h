#ifndef BUZZERCONTROL_H
#define BUZZERCONTROL_H

#define BUZZER_PIN 23

inline int buzzerAlert = 0;
inline unsigned long lastBuzz = 0;
inline bool buzzerState = false; 

inline void initBuzzer() {
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
    Serial.println("[INIT] Buzzer ready");
}

inline void setBuzzerAlert(int alertType) {
    buzzerAlert = alertType; 
}

inline void updateBuzzer() {
    unsigned long now = millis();
    if (buzzerAlert == 0) {
        digitalWrite(BUZZER_PIN, LOW);
        buzzerState = false;
        return;
    }

    // Different beep patterns
    if (now - lastBuzz >= 500) {
        lastBuzz = now;
        if (buzzerAlert == 1) { 
            buzzerState = !buzzerState;
            digitalWrite(BUZZER_PIN, buzzerState ? HIGH : LOW);
        } else if (buzzerAlert == 2) { 
            buzzerState = !buzzerState;
            digitalWrite(BUZZER_PIN, buzzerState ? HIGH : LOW);
            delay(100); 
        }
    }
}

#endif
