#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>

#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// Wi-Fi credentials 
#define WIFI_SSID "PLDTHOMEFIBRaef80_EXT"
#define WIFI_PASSWORD "MagbayadkaDidi@27"


#define API_KEY "AIzaSyBSXW22Lh3DkBjIw3hvP01-EESHseclMVg"
#define DATABASE_URL "https://pondsafeiot-7026c-default-rtdb.asia-southeast1.firebasedatabase.app"

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Pins 
#define TRIG_PIN 2
#define ECHO_PIN 4
#define RAIN_DO 22
#define RAIN_AO 19

float readDistanceInches() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  float distanceCm = duration * 0.034 / 2;
  float distanceInches = distanceCm / 2.54;
  return distanceInches;
}

void setup() {
  Serial.begin(115200);

  // Sensor setup
  pinMode(TRIG_PIN, OUTPUT);
  digitalWrite(TRIG_PIN, HIGH);  
  delay(50);

  pinMode(ECHO_PIN, INPUT);
  pinMode(RAIN_DO, INPUT);
  pinMode(RAIN_AO, INPUT);

  //  Wi-Fi 
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();
  Serial.print("Connected! IP address: ");
  Serial.println(WiFi.localIP());

 
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  
  auth.user.email = "icebearfhadia@gmail.com";
  auth.user.password = "zampond#01iotpondsafe0154";

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  float distance = readDistanceInches();

  String waterStatus;
  if (distance > 5.0) {
    waterStatus = "Normal water level";
  } else {
    waterStatus = "Overflow warning";
  }

  bool rainDetected = digitalRead(RAIN_DO) == LOW;
  int rainValue = analogRead(RAIN_AO);

  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.println(" inches");

  Serial.print("Water status: ");
  Serial.println(waterStatus);

  Serial.print("Rain detected: ");
  Serial.println(rainDetected ? "Yes" : "No");

  Serial.print("Rain intensity (AO): ");
  Serial.println(rainValue);

 
  if (Firebase.ready()) {
    Firebase.RTDB.setFloat(&fbdo, "/sensors/distance_inches", distance);
    Firebase.RTDB.setString(&fbdo, "/sensors/water_status", waterStatus);
    Firebase.RTDB.setString(&fbdo, "/sensors/rain_detected", rainDetected ? "Yes" : "No");
    Firebase.RTDB.setInt(&fbdo, "/sensors/rain_intensity", rainValue);

    if (fbdo.httpCode() > 0) {
      Serial.println("✅ Data sent to Firebase");
    } else {
      Serial.print("❌ Firebase error: ");
      Serial.println(fbdo.errorReason());
    }
  }

  delay(2000);
}
