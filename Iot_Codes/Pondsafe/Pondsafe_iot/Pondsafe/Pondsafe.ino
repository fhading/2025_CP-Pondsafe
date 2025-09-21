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

// Firebase priv credentials
#define API_KEY "AIzaSyBSXW22Lh3DkBjIw3hvP01-EESHseclMVg"
#define DATABASE_URL "https://pondsafeiot-7026c-default-rtdb.asia-southeast1.firebasedatabase.app"
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// NTP
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 28800;
const int daylightOffset_sec = 0;

// Wi-Fi & Captive Portal
DNSServer dnsServer;
WebServer server(80);
Preferences preferences;
String ssid, pass;

// LED
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

    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

    // Firebase
    auth.user.email = "icebearfhadia@gmail.com";
    auth.user.password = "zampond#01iotpondsafe0154";
    config.api_key = API_KEY;
    config.database_url = DATABASE_URL;

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
            int rainValue = readRainValue();
            String rainIntensity = getRainIntensity();

            
            Serial.printf("[RAIN ] Detected: %s | Raw AO: %d | Intensity: %s\n",
                          rainDetected ? "Yes" : "No", rainValue, rainIntensity.c_str());

            Serial.printf("[WATER] Distance: %.2f in | Level: %.2f%% -> Status: %s\n",
                          distance, waterPercent, waterStatus.c_str());

            digitalWrite(LED_PIN, (waterStatus == "OVERFLOW" || waterStatus == "WARNING" || rainDetected) ? HIGH : LOW);

            if (waterStatus == "OVERFLOW" || waterStatus == "WARNING") setBuzzerAlert(2);
            else if (rainDetected) setBuzzerAlert(1);
            else setBuzzerAlert(0);

            updateBuzzer();

            // data to Firebase
            if (Firebase.ready()) {
                struct tm timeinfo;
                if (getLocalTime(&timeinfo)) {
                    char dateString[20], timeString[20];
                    sprintf(dateString, "%02d-%02d-%04d", timeinfo.tm_mday, timeinfo.tm_mon + 1, timeinfo.tm_year + 1900);
                    sprintf(timeString, "%02d:%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);

                    String logPath = "/sensors/history/" + String(dateString) + "_" + String(timeString);

                    Firebase.RTDB.setFloat(&fbdo, logPath + "/distance_inches", distance);
                    Firebase.RTDB.setFloat(&fbdo, logPath + "/water_percent", waterPercent);
                    Firebase.RTDB.setString(&fbdo, logPath + "/water_status", waterStatus);
                    Firebase.RTDB.setString(&fbdo, logPath + "/rain_detected", rainDetected ? "Yes" : "No");
                    Firebase.RTDB.setInt(&fbdo, logPath + "/rain_intensity", rainValue);
                    Firebase.RTDB.setString(&fbdo, logPath + "/date", dateString);
                    Firebase.RTDB.setString(&fbdo, logPath + "/time", timeString);

                    if (fbdo.httpCode() > 0) Serial.println("[Firebase] ✅ Data saved!");
                    else Serial.printf("[Firebase] ❌ Error: %s\n", fbdo.errorReason().c_str());
                }
            }
        }
    }

    if (WiFi.getMode() == WIFI_AP) {
        dnsServer.processNextRequest();
        server.handleClient();
    }
}
