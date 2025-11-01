#include <Arduino.h>
#include <WiFi.h>
#include <DNSServer.h>
#include <WebServer.h>
#include <Preferences.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include "time.h"

#include "WaterLevel.h"
#include "RainSensor.h"
#include "BuzzerControl.h"
#include "CaptivePortal.h"

// ✅ new Firebase credentials
#define API_KEY "AIzaSyCSX68XYYHQqoswFcGoRVG_06Ijb-V_6xI"
#define DATABASE_URL "https://pondsafeiot-c370a-default-rtdb.asia-southeast1.firebasedatabase.app"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 28800;
const int daylightOffset_sec = 0;

// Wi-Fi & Captive Portal
DNSServer dnsServer;
WebServer server(80);
Preferences preferences;
String ssid, pass;

// LED Indicator
#define LED_PIN 18

unsigned long lastRead = 0;
const unsigned long readInterval = 1000;

void setup() {
    Serial.begin(115200);
    Serial.println("\n=== ESP32 PondSafe IoT Starting ===");

    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);

    initWaterLevel();
    initRainSensor();
    initBuzzer();

    preferences.begin("wifi", false);

    if (!connectWiFi(preferences, ssid, pass)) {
        Serial.println("No saved WiFi, starting Captive Portal...");
        startCaptivePortal(dnsServer, server, preferences);
        while (WiFi.getMode() == WIFI_AP) {
            dnsServer.processNextRequest();
            server.handleClient();
            delay(10);
        }
    }

    Serial.print("WiFi connected! IP: ");
    Serial.println(WiFi.localIP());

    // Wait for NTP time
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    struct tm timeinfo;
    while (!getLocalTime(&timeinfo)) {
        Serial.println("Waiting for NTP time...");
        delay(500);
    }

    // ✅ Firebase setup
    auth.user.email = "icebearfhadia@gmail.com";
    auth.user.password = "pondsafezam2025iot";
    config.api_key = API_KEY;
    config.database_url = DATABASE_URL;
    config.timeout.serverResponse = 10000; 
    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);
    Serial.println("Firebase initialized ✅");
}

void loop() {
    unsigned long now = millis();

    if (now - lastRead >= readInterval) {
        lastRead = now;

        float distance = readDistanceInches();
        if (distance != -1) {
            String waterStatus = getWaterStatus(distance);
            float waterPercent = getWaterLevelPercent(distance);
            bool rainDetected = checkRainDetected();
            String rainIntensity = readRainIntensity();

            Serial.printf("[RAIN ] Detected: %s | Intensity: %s\n",
                          rainDetected ? "Yes" : "No", rainIntensity.c_str());
            Serial.printf("[WATER] Distance: %.2f in | Level: %.2f%% -> Status: %s\n",
                          distance, waterPercent, waterStatus.c_str());

            digitalWrite(LED_PIN, (waterStatus == "OVERFLOW" || waterStatus == "WARNING" || rainDetected) ? HIGH : LOW);

            if (waterStatus == "OVERFLOW" || waterStatus == "WARNING") setBuzzerAlert(2);
            else if (rainDetected) setBuzzerAlert(1);
            else setBuzzerAlert(0);

            updateBuzzer();

            // Firebase write every 10 seconds
            static unsigned long lastFirebaseUpload = 0;
            const unsigned long firebaseInterval = 10000;

            if (Firebase.ready() && (now - lastFirebaseUpload >= firebaseInterval)) {
                lastFirebaseUpload = now;

                struct tm timeinfo;
                if (getLocalTime(&timeinfo)) {
                    char dateString[20], timeString[20];
                    sprintf(dateString, "%02d-%02d-%04d", timeinfo.tm_mday, timeinfo.tm_mon + 1, timeinfo.tm_year + 1900);
                    sprintf(timeString, "%02d:%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);

                    String logPath = "/sensors/history/" + String(dateString) + "_" + String(timeString);

                    bool ok = true;
                    ok &= Firebase.RTDB.setFloat(&fbdo, logPath + "/distance_inches", distance);
                    ok &= Firebase.RTDB.setFloat(&fbdo, logPath + "/water_percent", waterPercent);
                    ok &= Firebase.RTDB.setString(&fbdo, logPath + "/water_status", waterStatus);
                    ok &= Firebase.RTDB.setString(&fbdo, logPath + "/rain_detected", rainDetected ? "Yes" : "No");
                    ok &= Firebase.RTDB.setString(&fbdo, logPath + "/rain_intensity", rainIntensity);
                    ok &= Firebase.RTDB.setString(&fbdo, logPath + "/date", dateString);
                    ok &= Firebase.RTDB.setString(&fbdo, logPath + "/time", timeString);

                    if (ok) Serial.println("[Firebase] ✅ Data saved!");
                    else Serial.printf("[Firebase] ❌ Error: %s\n", fbdo.errorReason().c_str());
                }
            } else if (!Firebase.ready()) {
                Serial.println("[Firebase] ⚠️ Not ready, skipping upload...");
            }
        } 
    } 

    if (WiFi.getMode() == WIFI_AP) {
        dnsServer.processNextRequest();
        server.handleClient();
    }
} 
