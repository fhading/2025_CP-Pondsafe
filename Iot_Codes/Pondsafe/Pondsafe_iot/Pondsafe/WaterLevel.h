#ifndef WATERLEVEL_H
#define WATERLEVEL_H

#define TRIG_PIN 2
#define ECHO_PIN 4
#define MIN_DISTANCE_CM 2.0
#define MAX_DISTANCE_CM 300.0
#define NUM_SAMPLES 3

inline float readings[NUM_SAMPLES] = {0};
inline int sampleIndex = 0;

#define OVERFLOW_IN 5
#define WARNING_IN 12
#define MAX_DEPTH_IN 65

inline void initWaterLevel() {
    pinMode(TRIG_PIN, OUTPUT);
    digitalWrite(TRIG_PIN, LOW);
    delay(50);
    pinMode(ECHO_PIN, INPUT);
    Serial.println("[INIT] Water Level Sensor ready");
}

inline float readDistanceInches() {
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);

    long duration = pulseIn(ECHO_PIN, HIGH, 30000);
    float distanceCm = duration * 0.034 / 2;

    if (distanceCm < MIN_DISTANCE_CM || distanceCm > MAX_DISTANCE_CM) return -1;

    readings[sampleIndex] = distanceCm;
    sampleIndex = (sampleIndex + 1) % NUM_SAMPLES;

    float total = 0;
    for (int i = 0; i < NUM_SAMPLES; i++) total += readings[i];
    return (total / NUM_SAMPLES) / 2.54;
}

inline float getWaterLevelPercent(float distanceIn) {
    if (distanceIn <= OVERFLOW_IN) return 100;
    if (distanceIn >= MAX_DEPTH_IN) return 0;
    return (MAX_DEPTH_IN - distanceIn) / MAX_DEPTH_IN * 100;
}

inline String getWaterStatus(float distanceIn) {
    if (distanceIn <= OVERFLOW_IN) return "OVERFLOW";
    if (distanceIn <= WARNING_IN) return "WARNING";
    if (distanceIn < MAX_DEPTH_IN) return "NORMAL";
    return "EMPTY";
}

#endif
