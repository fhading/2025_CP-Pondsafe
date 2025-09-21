#ifndef STATUSLED_H
#define STATUSLED_H

#define STATUS_LED 18

void initLED() {
  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(STATUS_LED, LOW);
  Serial.println("[INIT] Status LED ready");
}

void blinkLED(int interval) {
  digitalWrite(STATUS_LED, HIGH);
  delay(interval);
  digitalWrite(STATUS_LED, LOW);
  delay(interval);
}

#endif
