#include <Arduino.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <esp_system.h>
#include <mbedtls/md.h>
#include <time.h>
#include "config.h"

#if BUTTON_GPIO < 0 || STATUS_LED_GPIO < 0
#error "Configura y verifica BUTTON_GPIO y STATUS_LED_GPIO en config.h antes de compilar."
#endif

constexpr unsigned long DEBOUNCE_MS = 80;
constexpr unsigned long RETRY_GUARD_MS = 3000;
unsigned long lastActivation = 0;
bool previousPressed = false;

String randomHex(size_t bytes) {
  static const char *hex = "0123456789abcdef";
  String value;
  value.reserve(bytes * 2);
  for (size_t i = 0; i < bytes; ++i) {
    uint8_t current = static_cast<uint8_t>(esp_random());
    value += hex[current >> 4];
    value += hex[current & 0x0F];
  }
  return value;
}

String hmacSha256(const String &message) {
  byte digest[32];
  mbedtls_md_context_t context;
  mbedtls_md_init(&context);
  const mbedtls_md_info_t *info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  mbedtls_md_setup(&context, info, 1);
  mbedtls_md_hmac_starts(&context,
      reinterpret_cast<const unsigned char *>(DEVICE_SECRET), strlen(DEVICE_SECRET));
  mbedtls_md_hmac_update(&context,
      reinterpret_cast<const unsigned char *>(message.c_str()), message.length());
  mbedtls_md_hmac_finish(&context, digest);
  mbedtls_md_free(&context);
  String result;
  result.reserve(64);
  for (byte value : digest) {
    if (value < 16) result += '0';
    result += String(value, HEX);
  }
  return result;
}

bool timeIsReady() {
  return time(nullptr) > 1700000000;
}

bool sendAlert() {
  if (WiFi.status() != WL_CONNECTED || !timeIsReady()) return false;
  const long timestamp = static_cast<long>(time(nullptr));
  const String nonce = randomHex(16);
  const String requestId = String(DEVICE_ID) + ":" + String(timestamp) + ":" + nonce;
  const String canonical = String(DEVICE_ID) + "\n" + ALERT_LEVEL + "\n" +
      String(timestamp) + "\n" + nonce + "\n" + requestId;
  const String signature = hmacSha256(canonical);
  const String body = "{\"deviceId\":\"" + String(DEVICE_ID) +
      "\",\"nivel\":\"" + ALERT_LEVEL +
      "\",\"timestamp\":" + String(timestamp) +
      ",\"nonce\":\"" + nonce +
      "\",\"idempotencyKey\":\"" + requestId +
      "\",\"signature\":\"" + signature + "\"}";

  WiFiClientSecure client;
  client.setCACert(TLS_ROOT_CA);
  HTTPClient http;
  if (!http.begin(client, ENDPOINT_URL)) return false;
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);
  const int status = http.POST(body);
  http.end();
  return status >= 200 && status < 300;
}

void connectNetwork() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  const unsigned long startedAt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startedAt < 15000) delay(250);
  if (WiFi.status() == WL_CONNECTED) configTime(0, 0, "pool.ntp.org", "time.google.com");
}

void setup() {
  pinMode(BUTTON_GPIO, INPUT_PULLUP);
  pinMode(STATUS_LED_GPIO, OUTPUT);
  digitalWrite(STATUS_LED_GPIO, LOW);
  connectNetwork();
}

void loop() {
  const bool pressed = digitalRead(BUTTON_GPIO) == LOW;
  if (pressed && !previousPressed && millis() - lastActivation >= RETRY_GUARD_MS) {
    delay(DEBOUNCE_MS);
    if (digitalRead(BUTTON_GPIO) == LOW) {
      lastActivation = millis();
      const bool delivered = sendAlert();
      digitalWrite(STATUS_LED_GPIO, delivered ? HIGH : LOW);
      delay(delivered ? 1000 : 250);
      digitalWrite(STATUS_LED_GPIO, LOW);
    }
  }
  previousPressed = pressed;
  if (WiFi.status() != WL_CONNECTED) connectNetwork();
  delay(20);
}
