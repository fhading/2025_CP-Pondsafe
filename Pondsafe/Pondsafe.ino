#include <FS.h>
#include <SPIFFS.h>
#include <ArduinoJson.h>

#define TRIG_PIN 2    
#define ECHO_PIN 4   
#define RAIN_PIN 19  

void setup() {
  Serial.begin(115200);

  if (!SPIFFS.begin(true)) {
    Serial.println("SPIFFS Mount Failed!");
  } else {
    Serial.println("SPIFFS Mounted.");
  }

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(RAIN_PIN, INPUT);   
}

float readDistanceInches() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000);

  if (duration == 0) {
    return -1;
  }

  float distanceCm = duration * 0.0343 / 2.0;
  float distanceInches = distanceCm / 2.54;

  return distanceInches;
}

void saveData(float distance, bool rainDetected, int rainValue) {
  File file = SPIFFS.open("/data.json", "r");
  DynamicJsonDocument doc(2048);

  if (file) {
    DeserializationError error = deserializeJson(doc, file);
    file.close();
    if (error) {
      doc.clear();
      doc["records"] = JsonArray();
    }
  } else {
    doc["records"] = JsonArray();
  }

  JsonObject entry = doc["records"].createNestedObject();
  entry["distance_inches"] = distance;
  entry["rain_detected"] = rainDetected;
  entry["rain_value"] = rainValue;   
  entry["timestamp"] = millis();

  file = SPIFFS.open("/data.json", "w");
  if (file) {
    serializeJsonPretty(doc, file);
    file.close();
    Serial.println("Data saved to data.json");
  } else {
    Serial.println("Failed to open data.json for writing");
  }
}

void loop() {
  float distance = readDistanceInches();

  if (distance < 0) {
    Serial.println("No echo received");
  } else {
    Serial.print("Distance: ");
    Serial.print(distance, 2);
    Serial.println(" inches");
  }

  int rainValue = digitalRead(RAIN_PIN);  
  bool rainDetected = (rainValue == LOW);  

  if (rainDetected) {
    Serial.println("Rain detected ");
  } else {
    Serial.println("No rain ");
  }


  saveData(distance, rainDetected, rainValue);

  delay(5000);
}
