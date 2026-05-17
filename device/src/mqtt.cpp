/*
 * ====================================================================
 * Bai thuc hanh: MQTT - ESP32 (Wokwi) <-> ThingsBoard Cloud
 * - 8 LED dieu khien qua RPC (GPIO 13, 14, 15, 12, 33, 18, 19, 21)
 * - 4 cam bien Analog: LDR, bien tro, NTC, do am dat
 * - 4 cam bien Digital: nut nhan, cong tac, PIR, water-level
 * ====================================================================
 */
#include <WiFi.h>
#include <WiFiClient.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Arduino.h>

// ---------- 1. Cau hinh nguoi dung ----------
const char *WIFI_SSID = "Wokwi-GUEST";
const char *WIFI_PASS = "";
const char *TB_SERVER = "thingsboard.cloud";
const uint16_t TB_PORT = 1883;
const char *TB_TOKEN = "hlbzkwx28cc5hy9uydbv";

// ---------- 2. Dinh nghia chan phan cung ----------

const uint8_t LED_PINS[8] = {13, 14, 23, 12, 33, 18, 19, 21};
#define A1_LDR 36  // Quang tro (nối với chân VP trên Wokwi)
#define A2_POT 39  // Bien tro (nối với chân VN trên Wokwi)
#define A3_NTC 34  // Cam bien nhiet do (NTC)
#define A4_SOIL 35 // Do am dat

#define D1_BTN 25  // Nut nhan, INPUT_PULLUP
#define D2_SW 26   // Cong tac, INPUT_PULLUP
#define D3_PIR 27  // PIR, INPUT
#define D4_WLVL 32 // Water level, INPUT_PULLUP

// ---------- 3. Bien toan cuc ----------
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);
bool ledState[8] = {false};
unsigned long lastTelemetry = 0;
const unsigned long TELE_INTERVAL = 5000; // 5 giay
float lastTempC = -999.0;                 // Nhiệt độ trước đó
unsigned long lastEventTime = 0;          // Thời gian gửi trước đó

// ---------- 4. Tien xu ly ----------
void connectWiFi();
void connectMQTT();
void onMqttMessage(char *topic, byte *payload, unsigned int length);
void publishTelemetry();
void publishLedStates();
void handleRpc(const char *topic, const String &payload);

// ====================================================================
// SETUP
// ====================================================================
void setup()
{
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=== PTIT ISP-Lab :: ESP32 + ThingsBoard MQTT ===");

  // Khoi tao chan LED
  for (uint8_t i = 0; i < 8; i++)
  {
    pinMode(LED_PINS[i], OUTPUT);
    digitalWrite(LED_PINS[i], LOW);
  }

  pinMode(D1_BTN, INPUT_PULLUP);
  pinMode(D2_SW, INPUT_PULLUP);
  pinMode(D3_PIR, INPUT);
  pinMode(D4_WLVL, INPUT_PULLUP);

  analogReadResolution(12); // 0..4095

  connectWiFi();
  mqtt.setServer(TB_SERVER, TB_PORT);
  mqtt.setCallback(onMqttMessage);
  mqtt.setBufferSize(512);
}

// ====================================================================
// LOOP
// ====================================================================
void loop()
{
  if (WiFi.status() != WL_CONNECTED)
    connectWiFi();
  if (!mqtt.connected())
    connectMQTT();
  mqtt.loop();

  unsigned long now = millis();
  if (now - lastTelemetry >= TELE_INTERVAL)
  {
    lastTelemetry = now;
    publishTelemetry();
  }
}

// ====================================================================
// KET NOI WIFI
// ====================================================================
void connectWiFi()
{
  Serial.printf("Ket noi Wi-Fi [%s] ...\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(300);
    Serial.print('.');
  }
  Serial.printf("\n[OK] IP = %s\n", WiFi.localIP().toString().c_str());
}

// ====================================================================
// KET NOI MQTT
// ====================================================================
void connectMQTT()
{
  while (!mqtt.connected())
  {
    Serial.print("Ket noi ThingsBoard MQTT ... ");
    String clientId = "esp32-" + String((uint32_t)ESP.getEfuseMac(), HEX);

    // ThingsBoard: username = AccessToken, password = rong
    if (mqtt.connect(clientId.c_str(), TB_TOKEN, NULL))
    {
      Serial.println("OK");
      mqtt.subscribe("v1/devices/me/rpc/request/+", 1);
      publishLedStates(); // dong bo trang thai LED ban dau
    }
    else
    {
      Serial.printf("LOI rc=%d, thu lai sau 3s\n", mqtt.state());
      delay(3000);
    }
  }
}

// ====================================================================
// CALLBACK - NHAN BAN TIN MQTT
// ====================================================================
void onMqttMessage(char *topic, byte *payload, unsigned int length)
{
  String msg;
  for (unsigned int i = 0; i < length; i++)
    msg += (char)payload[i];
  Serial.printf("[MQTT] %s -> %s\n", topic, msg.c_str());
  handleRpc(topic, msg);
}

// ====================================================================
// XU LY LENH RPC
// ====================================================================
void handleRpc(const char *topic, const String &payload)
{
  // topic dang: v1/devices/me/rpc/request/{requestId}
  String tStr = String(topic);
  int pos = tStr.lastIndexOf('/');
  String reqId = tStr.substring(pos + 1);

  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, payload);
  if (err)
  {
    Serial.printf("[RPC] Loi parse JSON: %s\n", err.c_str());
    return;
  }

  const char *method = doc["method"];
  if (!method)
    return;

  StaticJsonDocument<128> resp;

  // ---- Lenh: setLed1 ... setLed8 ----
  if (strncmp(method, "setLed", 6) == 0)
  {
    int idx = atoi(method + 6); // 1..8
    if (idx >= 1 && idx <= 8)
    {
      bool val = doc["params"];
      ledState[idx - 1] = val;
      digitalWrite(LED_PINS[idx - 1], val ? HIGH : LOW);
      resp["led"] = idx;
      resp["state"] = val;
    }
  }
  // ---- Lenh: getLedStates ----
  else if (strcmp(method, "getLedStates") == 0)
  {
    JsonArray arr = resp.createNestedArray("leds");
    for (uint8_t i = 0; i < 8; i++)
      arr.add(ledState[i]);
  }
  // ---- Lenh: setAll ----
  else if (strcmp(method, "setAll") == 0)
  {
    bool val = doc["params"];
    for (uint8_t i = 0; i < 8; i++)
    {
      ledState[i] = val;
      digitalWrite(LED_PINS[i], val ? HIGH : LOW);
    }
    resp["all"] = val;
  }

  // Tra loi RPC
  String rTopic = "v1/devices/me/rpc/response/" + reqId;
  char buf[128];
  size_t n = serializeJson(resp, buf);
  mqtt.publish(rTopic.c_str(), (uint8_t *)buf, n, false);

  // Cap nhat trang thai LED len server qua attribute
  publishLedStates();
}

// ====================================================================
// GUI TELEMETRY CAM BIEN
// ====================================================================
void publishTelemetry()
{
  // Doc analog
  int rawLdr = analogRead(A1_LDR);
  int rawPot = analogRead(A2_POT);
  int rawNtc = analogRead(A3_NTC);
  int rawSoil = analogRead(A4_SOIL);

  // Quy doi vat ly
  float lux = map(rawLdr, 0, 4095, 0, 1000); // 0..1000 lux
  float potVolt = rawPot * 3.3 / 4095.0;     // 0..3.3 V

  // Tinh nhiet do NTC chuan cua Wokwi
  // (Cong thuc logarit thay vi LM35 de cho ra do C chinh xac)
  float tempC = 0.0;
  if (rawNtc > 0 && rawNtc < 4095)
  {
    const float BETA = 3950.0;
    tempC = 1.0 / (log(1.0 / (4095.0 / rawNtc - 1.0)) / BETA + 1.0 / 298.15) - 273.15;
  }

  float soilPct = 100.0 - (rawSoil * 100.0 / 4095.0); // % am

  // Doc digital
  int btn = digitalRead(D1_BTN) == LOW ? 1 : 0; // active-LOW
  int sw = digitalRead(D2_SW) == LOW ? 1 : 0;
  int pir = digitalRead(D3_PIR);
  int wlvl = digitalRead(D4_WLVL) == LOW ? 1 : 0;

  // Tao JSON telemetry
  StaticJsonDocument<384> tele;
  tele["lux"] = lux;
  tele["pot_v"] = potVolt;
  tele["temp_c"] = tempC;
  tele["soil_pct"] = soilPct;
  tele["btn"] = btn;
  tele["sw"] = sw;
  tele["pir"] = pir;
  tele["wlvl"] = wlvl;
  tele["rssi"] = WiFi.RSSI();

  char buf[384];
  size_t n = serializeJson(tele, buf);
  mqtt.publish("v1/devices/me/telemetry", (uint8_t *)buf, n, false);
  Serial.printf("[TX] %s\n", buf);
}

// ====================================================================
// GUI TRANG THAI LED LEN ATTRIBUTE (de dashboard dong bo)
// ====================================================================
void publishLedStates()
{
  StaticJsonDocument<256> attr;
  for (uint8_t i = 0; i < 8; i++)
  {
    String key = "led" + String(i + 1);
    attr[key] = ledState[i];
  }
  char buf[256];
  size_t n = serializeJson(attr, buf);
  mqtt.publish("v1/devices/me/attributes", (uint8_t *)buf, n, false);
}