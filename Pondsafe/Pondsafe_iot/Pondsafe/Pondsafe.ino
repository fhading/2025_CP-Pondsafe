#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include "time.h"

// Wi-Fi credentials 
#define WIFI_SSID "PLDTHOMEFIBRaef80_EXT"
#define WIFI_PASSWORD "MagbayadkaDidi@27"

#define API_KEY "AIzaSyBSXW22Lh3DkBjIw3hvP01-EESHseclMVg"
#define DATABASE_URL "https://pondsafeiot-7026c-default-rtdb.asia-southeast1.firebasedatabase.app"

// Firebase 
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Pins 
#define TRIG_PIN 2
#define ECHO_PIN 4
#define RAIN_DO 22
#define RAIN_AO 19
#define BUZZER_PIN 23   
// Rain detection timing
unsigned long rainStartTime = 0;
bool isRainingConfirmed = false;

// NTP time config
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 28800;  // GMT+8 Philippines
const int daylightOffset_sec = 0;

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
  pinMode(BUZZER_PIN, OUTPUT);   
  digitalWrite(BUZZER_PIN, LOW); 

  // Wi-Fi 
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();
  Serial.print("Connected! IP address: ");
  Serial.println(WiFi.localIP());

  // NTP time
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

  // Firebase Auth
  auth.user.email = "icebearfhadia@gmail.com";
  auth.user.password = "zampond#01iotpondsafe0154";

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

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

  // Raw rain readings
  bool rainRaw = digitalRead(RAIN_DO) == LOW;
  int rainValue = analogRead(RAIN_AO);

  // Rain suspense logic
  if (rainRaw) {
    if (rainStartTime == 0) {
      rainStartTime = millis();  
    } else if (millis() - rainStartTime >= 8000) {
      isRainingConfirmed = true; 
    }
  } else {
    rainStartTime = 0;          
    isRainingConfirmed = false; 
  }

  
  if (isRainingConfirmed || waterStatus == "Overflow warning") {
   
    if ((millis() / 200) % 2 == 0) {
      digitalWrite(BUZZER_PIN, HIGH);
    } else {
      digitalWrite(BUZZER_PIN, LOW);
    }
  } else {
    digitalWrite(BUZZER_PIN, LOW); 
  }

 
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println(" Failed to obtain time");
    delay(1000);
    return;
  }

  char dateString[20];
  sprintf(dateString, "%02d-%02d-%04d", timeinfo.tm_mday, timeinfo.tm_mon + 1, timeinfo.tm_year + 1900);

  char timeString[20];
  sprintf(timeString, "%02d:%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);

  String logPath = "/sensors/history/";
  logPath += String(dateString) + "_" + String(timeString);

 
  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.println(" inches");

  Serial.print("Water status: ");
  Serial.println(waterStatus);

  Serial.print("Rain confirmed (8s suspense): ");
  Serial.println(isRainingConfirmed ? "Yes" : "No");

  Serial.print("Rain intensity (AO): ");
  Serial.println(rainValue);

  Serial.print("Date: ");
  Serial.print(dateString);
  Serial.print(" Time: ");
  Serial.println(timeString);

 
  if (Firebase.ready()) {
    Firebase.RTDB.setFloat(&fbdo, logPath + "/distance_inches", distance);
    Firebase.RTDB.setString(&fbdo, logPath + "/water_status", waterStatus);
    Firebase.RTDB.setString(&fbdo, logPath + "/rain_detected", isRainingConfirmed ? "Yes" : "No");
    Firebase.RTDB.setInt(&fbdo, logPath + "/rain_intensity", rainValue);
    Firebase.RTDB.setString(&fbdo, logPath + "/date", dateString);
    Firebase.RTDB.setString(&fbdo, logPath + "/time", timeString);

    if (fbdo.httpCode() > 0) {
      Serial.println("✅ Data saved to Firebase history");
    } else {
      Serial.print("❌ Firebase error: ");
      Serial.println(fbdo.errorReason());
    }
  }

  delay(3000); 
}
