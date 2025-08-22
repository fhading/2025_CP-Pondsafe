#include <Arduino.h>
#include <ArduinoJson.h>
#include <FS.h>
#include <SPIFFS.h>

// Ultrasonic pins
#define TRIG_PIN 2   // D2
#define ECHO_PIN 4   // D4

// Rain sensor pin
#define RAIN_PIN 19  // D19

void setup() {
  Serial.begin(115200);

  // Sensor setup
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(RAIN_PIN, INPUT);

  // Start SPIFFS
  if (!SPIFFS.begin(true)) {
    Serial.println("SPIFFS Mount Failed");
    return;
  }
}

float readDistanceInches() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH);
  float distanceCM = duration * 0.034 / 2;
  return distanceCM / 2.54; // convert to inches
}

void loop() {
  float distance = readDistanceInches();
  bool rainDetected = digitalRead(RAIN_PIN) == LOW; // LOW usually means wet

  // Print to serial
  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.println(" inches");

  if (rainDetected) {
    Serial.println("Rain detected");
  } else {
    Serial.println("No rain");
  }

  // Create JSON object
  DynamicJsonDocument doc(256);
  doc["distance_inches"] = distance;
  doc["rain_detected"] = rainDetected ? "yes" : "no";

  // Save JSON to SPIFFS
  File file = SPIFFS.open("/data.json", FILE_WRITE);
  if (!file) {
    Serial.println("Failed to open file for writing");
    return;
  }
  serializeJson(doc, file);
  file.close();

  Serial.println("Data saved to data.json\n");

  delay(3000); // wait 3 seconds
}
