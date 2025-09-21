#pragma once
#include <WiFi.h>
#include <DNSServer.h>
#include <WebServer.h>
#include <Preferences.h>

// Wi-Fi setup
void handleRoot(Wpage ebServer &server) {
    String html = R"rawliteral(
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>ESP32 Wi-Fi Setup</title>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap');
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
                font-family: 'Roboto', sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                background: linear-gradient(135deg, #667eea, #764ba2);
                color: #333;
            }
            .card {
                background: rgba(255, 255, 255, 0.95);
                padding: 40px;
                border-radius: 20px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.3);
                width: 100%;
                max-width: 400px;
                text-align: center;
                transition: transform 0.3s;
            }
            .card:hover { transform: translateY(-5px); }
            h2 {
                margin-bottom: 25px;
                color: #333;
                font-weight: 700;
            }
            input {
                width: 100%;
                padding: 15px;
                margin-bottom: 20px;
                border-radius: 12px;
                border: 1px solid #ccc;
                font-size: 15px;
                transition: border 0.3s, box-shadow 0.3s;
            }
            input:focus {
                border-color: #667eea;
                box-shadow: 0 0 8px rgba(102,126,234,0.5);
                outline: none;
            }
            button {
                width: 100%;
                padding: 15px;
                border-radius: 12px;
                font-size: 16px;
                font-weight: bold;
                border: none;
                cursor: pointer;
                background: linear-gradient(135deg, #667eea, #764ba2);
                color: #fff;
                transition: background 0.3s, transform 0.2s;
            }
            button:hover {
                background: linear-gradient(135deg, #5563c1, #5a3e99);
                transform: scale(1.05);
            }
            p {
                margin-top: 15px;
                font-size: 14px;
                color: #555;
            }
        </style>
    </head>
    <body>
        <div class="card">
            <h2>ESP32 Wi-Fi Setup</h2>
            <form action="/save" method="POST">
                <input type="text" name="ssid" placeholder="Wi-Fi SSID" required>
                <input type="password" name="pass" placeholder="Password" required>
                <button type="submit">Save & Connect</button>
            </form>
            <p>PondSafe IoT Wi-Fi.</p>
        </div>
    </body>
    </html>
    )rawliteral";

    server.send(200, "text/html", html);
}


void handleSaved(WebServer &server) {
    String html = R"rawliteral(
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Wi-Fi Saved</title>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap');
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
                font-family: 'Roboto', sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                background: linear-gradient(135deg, #667eea, #764ba2);
                color: #333;
            }
            .card {
                background: rgba(255, 255, 255, 0.95);
                padding: 40px;
                border-radius: 20px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.3);
                width: 100%;
                max-width: 400px;
                text-align: center;
                transition: transform 0.3s;
            }
            .card:hover { transform: translateY(-5px); }
            h2 {
                margin-bottom: 25px;
                color: #333;
                font-weight: 700;
            }
            p {
                font-size: 16px;
                margin-bottom: 20px;
                color: #555;
            }
            a {
                text-decoration: none;
                display: inline-block;
                padding: 12px 25px;
                border-radius: 12px;
                background: linear-gradient(135deg, #667eea, #764ba2);
                color: #fff;
                font-weight: 500;
                transition: transform 0.2s, background 0.3s;
            }
            a:hover {
                transform: scale(1.05);
                background: linear-gradient(135deg, #5563c1, #5a3e99);
            }
        </style>
    </head>
    <body>
        <div class="card">
            <h2>✅ Wi-Fi Saved!</h2>
            <p>Your credentials have been saved. Please restart the ESP32 to connect.</p>
            
        </div>
    </body>
    </html>
    )rawliteral";

    server.send(200, "text/html", html);
}


bool connectWiFi(Preferences &prefs, String &ssid, String &pass) {
    ssid = prefs.getString("ssid", "");
    pass = prefs.getString("pass", "");

    if (ssid == "") return false;

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid.c_str(), pass.c_str());

    Serial.print("[WiFi] Connecting to ");
    Serial.println(ssid);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\n[WiFi] Connected!");
        return true;
    } else {
        Serial.println("\n[WiFi] Connection failed!");
        return false;
    }
}

// Captive Portal
void startCaptivePortal(DNSServer &dnsServer, WebServer &server, Preferences &prefs) {
    WiFi.mode(WIFI_AP);
    WiFi.softAP("PondSafe_AP");
    IPAddress IP = WiFi.softAPIP();
    Serial.print("[AP] Started AP at IP: ");
    Serial.println(IP);

    dnsServer.start(53, "*", IP);

    server.on("/", [&server]() { handleRoot(server); });

    
    server.on("/save", [&prefs, &server]() {
        String ssid = server.arg("ssid");
        String pass = server.arg("pass");

        prefs.putString("ssid", ssid);
        prefs.putString("pass", pass);

        handleSaved(server);
        Serial.println("[WiFi] Credentials saved. Restart ESP32 to connect.");
    });

    server.begin();
}
