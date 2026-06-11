#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ==========================================
// 1. CẤU HÌNH PINOUT PHẦN CỨNG
// ==========================================
#define DUST_LED_PIN 25
#define DUST_ANALOG_PIN 34
#define MQ135_ANALOG_PIN 35
#define DHTPIN 4
#define DHTTYPE DHT11

#define FAN_PWM_PIN 18
#define FAN_RELAY_PIN 32

#define MIST_RELAY_PIN 33
#define WATER_SWITCH_PIN 2

// ==========================================
// 2. CẤU HÌNH HỆ SỐ & MẠNG
// ==========================================
const float V_C = 5.0, R_L = 10.0, R_0 = 1.87;
const float CONST_A = 116.602, CONST_B = -2.769;
const float EMA_ALPHA = 0.1;

const int pwmChannel = 4;
const int pwmFreq = 25000;
const int pwmResolution = 8;

#define WIFI_SSID "Huy Quang"
#define WIFI_PASSWORD "12345678"
#define TB_SERVER "thingsboard.cloud"
#define TB_PORT 1883
#define TB_TOKEN "zuzo3dbhbi4qtsz85l3l"

// ==========================================
// 3. ĐỐI TƯỢNG & BIẾN TOÀN CỤC
// ==========================================
DHT dht(DHTPIN, DHTTYPE);
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);
LiquidCrystal_I2C lcd(0x27, 16, 2);

struct SystemEnvironment
{
  float dust_ug;
  float gas_ppm;
  float temperature;
  float humidity;
  bool water_low;
};
SystemEnvironment currentEnv = {0.0, 0.0, 0.0, 0.0, false};
SemaphoreHandle_t envMutex;

bool autoMode = true;
int fanLevel = 0;
int currentFanLevel = 0;
unsigned long lastFanChangeTime = 0;
volatile bool mistOn = false;
volatile bool waterLow = false;

void connectMQTT();
void onMqttMessage(char *topic, byte *payload, unsigned int length);

// ==========================================
// 4. HÀM CÔNG CỤ (UTILITIES)
// ==========================================
float filterEMA(float newValue, float previousValue, float alpha)
{
  if (previousValue < 0.0)
    return newValue;
  return (alpha * newValue) + ((1.0 - alpha) * previousValue);
}

// alarmOn removed

// ==========================================
// 5. TASKS: ĐỌC CẢM BIẾN
// ==========================================
void dhtTask(void *pvParameters)
{
  dht.begin();
  for (;;)
  {
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    if (!isnan(h) && !isnan(t))
    {
      if (xSemaphoreTake(envMutex, portMAX_DELAY))
      {
        currentEnv.temperature = t;
        currentEnv.humidity = h;
        xSemaphoreGive(envMutex);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(2000));
  }
}

void dustSensorTask(void *pvParameters)
{
  static float filteredDust = -1.0;
  for (;;)
  {
    digitalWrite(DUST_LED_PIN, LOW);
    delayMicroseconds(280);
    int rawDust = analogRead(DUST_ANALOG_PIN);
    delayMicroseconds(40);
    digitalWrite(DUST_LED_PIN, HIGH);

    float voltage = rawDust * (3.3 / 4095.0);
    float dustDensity_mg = 0.17 * voltage - 0.1;
    if (dustDensity_mg < 0)
      dustDensity_mg = 0;

    float rawUg = dustDensity_mg * 1000.0;
    filteredDust = filterEMA(rawUg, filteredDust, EMA_ALPHA);

    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      currentEnv.dust_ug = filteredDust;
      xSemaphoreGive(envMutex);
    }
    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

void mq135Task(void *pvParameters)
{
  const TickType_t WARM_UP_TIME = pdMS_TO_TICKS(60000);
  TickType_t startTime = xTaskGetTickCount();
  bool isReady = false;
  static float filteredGas = -1.0;

  for (;;)
  {
    int rawGas = analogRead(MQ135_ANALOG_PIN);
    if (!isReady && (xTaskGetTickCount() - startTime) >= WARM_UP_TIME)
    {
      isReady = true;
    }

    if (isReady)
    {
      float v_esp = rawGas * (3.3 / 4095.0);
      float v_rl = constrain(v_esp * 2.0, 0.01, 4.8);
      float r_s = R_L * ((V_C / v_rl) - 1.0);
      float rawPpm = CONST_A * pow((r_s / R_0), CONST_B);

      filteredGas = filterEMA(rawPpm, filteredGas, EMA_ALPHA);

      if (xSemaphoreTake(envMutex, portMAX_DELAY))
      {
        currentEnv.gas_ppm = filteredGas;
        xSemaphoreGive(envMutex);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(2000));
  }
}

void waterSwitchTask(void *pvParameters)
{
  for (;;)
  {
    bool localWaterLow = (digitalRead(WATER_SWITCH_PIN) == HIGH);
    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      currentEnv.water_low = localWaterLow;
      xSemaphoreGive(envMutex);
    }
    waterLow = localWaterLow;
    if (waterLow && mistOn)
    {
      mistOn = false;
    }
    vTaskDelay(pdMS_TO_TICKS(500));
  }
}

// ==========================================
// 6. TASKS: ĐIỀU KHIỂN & HIỂN THỊ
// ==========================================
void controlTask(void *pvParameters)
{
  for (;;)
  {
    if (fanLevel != currentFanLevel)
    {
      currentFanLevel = fanLevel;
      if (currentFanLevel == 0)
        digitalWrite(FAN_RELAY_PIN, LOW);
      else
        digitalWrite(FAN_RELAY_PIN, HIGH);

      int percent = (currentFanLevel == 1)   ? 70
                    : (currentFanLevel == 2) ? 85
                    : (currentFanLevel == 3) ? 100
                                             : 0;

      int duty = map(percent, 0, 100, 255, 0);
      ledcWrite(pwmChannel, duty);
    }

    if (waterLow)
    {
      mistOn = false;
    }
    digitalWrite(MIST_RELAY_PIN, mistOn ? HIGH : LOW);

    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

void displayTask(void *pvParameters)
{
  char rowBuffer[17];
  for (;;)
  {
    SystemEnvironment tempEnv;
    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      tempEnv = currentEnv;
      xSemaphoreGive(envMutex);
    }

    // Dòng 1: Nhiệt độ & Độ ẩm + Phun sương / Cạn nước
    lcd.setCursor(0, 0);
    char statusChar[4] = "M:0";
    if (tempEnv.water_low)
    {
      strcpy(statusChar, "W:L");
    }
    else if (mistOn)
    {
      strcpy(statusChar, "M:1");
    }
    snprintf(rowBuffer, sizeof(rowBuffer), "T:%4.1fCH:%2.0f%% %s", tempEnv.temperature, tempEnv.humidity, statusChar);
    lcd.print(rowBuffer);

    // Dòng 2: Bụi & Khí Gas
    lcd.setCursor(0, 1);
    snprintf(rowBuffer, sizeof(rowBuffer), "D:%4.0fu G:%4.0fp   ", tempEnv.dust_ug, tempEnv.gas_ppm);
    lcd.print(rowBuffer);

    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

// ==========================================
// 7. TASKS: GIAO TIẾP MQTT
// ==========================================
void connectMQTT()
{
  while (!mqtt.connected())
  {
    String clientId = "esp32-" + String((uint32_t)ESP.getEfuseMac(), HEX);
    if (mqtt.connect(clientId.c_str(), TB_TOKEN, NULL))
    {
      mqtt.subscribe("v1/devices/me/rpc/request/+");
    }
    else
    {
      vTaskDelay(pdMS_TO_TICKS(3000));
    }
  }
}

void onMqttMessage(char *topic, byte *payload, unsigned int length)
{
  String msg;
  for (unsigned int i = 0; i < length; i++)
    msg += (char)payload[i];

  // 1. Tách Request ID ra khỏi Topic
  String topicStr = String(topic);
  int lastSlash = topicStr.lastIndexOf('/');
  String requestId = topicStr.substring(lastSlash + 1);

  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, msg);
  if (error)
    return;

  String method = doc["method"].as<String>();

  // 2. Xử lý logic phần cứng
  if (method == "setAutoMode")
  {
    autoMode = doc["params"].as<bool>();
  }
  else if (method == "setFan")
  {
    if (doc["params"].is<int>()) {
      fanLevel = doc["params"].as<int>();
    } else {
      String rawParam = doc["params"].as<String>();
      fanLevel = rawParam.toInt();
    }
  }
  else if (method == "setMist")
  {
    mistOn = doc["params"].as<bool>();
  }

  String responseTopic = "v1/devices/me/rpc/response/" + requestId;
  mqtt.publish(responseTopic.c_str(), "{\"status\":\"success\"}");
}

void mqttTask(void *pvParameters)
{
  TickType_t lastPublishTime = xTaskGetTickCount();
  const TickType_t PUBLISH_INTERVAL = pdMS_TO_TICKS(5000);

  for (;;)
  {
    if (WiFi.status() == WL_CONNECTED)
    {
      if (!mqtt.connected())
        connectMQTT();
      mqtt.loop();

      if ((xTaskGetTickCount() - lastPublishTime) >= PUBLISH_INTERVAL)
      {
        lastPublishTime = xTaskGetTickCount();
        SystemEnvironment tempEnv;

        if (xSemaphoreTake(envMutex, portMAX_DELAY))
        {
          tempEnv = currentEnv;
          xSemaphoreGive(envMutex);
        }

        StaticJsonDocument<256> doc;
        doc["temperature"] = tempEnv.temperature;
        doc["humidity"] = tempEnv.humidity;
        doc["dust_ug"] = serialized(String(tempEnv.dust_ug, 2));
        doc["gas_ppm"] = serialized(String(tempEnv.gas_ppm, 2));
        doc["auto_mode"] = autoMode;
        doc["fan_level"] = currentFanLevel;
        doc["mist_on"] = mistOn;
        doc["water_low"] = tempEnv.water_low;

        char buffer[256];
        size_t n = serializeJson(doc, buffer);
        mqtt.publish("v1/devices/me/telemetry", (uint8_t *)buffer, n, false);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

// ==========================================
// 8. SETUP & LOOP
// ==========================================
void setup()
{
  Serial.begin(115200);

  pinMode(DUST_LED_PIN, OUTPUT);
  pinMode(FAN_RELAY_PIN, OUTPUT);
  pinMode(MIST_RELAY_PIN, OUTPUT);

  digitalWrite(FAN_RELAY_PIN, LOW);
  digitalWrite(MIST_RELAY_PIN, LOW);
  pinMode(WATER_SWITCH_PIN, INPUT_PULLUP);

  ledcSetup(pwmChannel, pwmFreq, pwmResolution);
  ledcAttachPin(FAN_PWM_PIN, pwmChannel);

  // Đã bổ sung khởi tạo LCD
  lcd.init();
  lcd.backlight();

  envMutex = xSemaphoreCreateMutex();

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED)
    delay(500);

  mqtt.setServer(TB_SERVER, TB_PORT);
  mqtt.setCallback(onMqttMessage);
  mqtt.setBufferSize(512);

  xTaskCreatePinnedToCore(dhtTask, "DHT_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(dustSensorTask, "Dust_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(mq135Task, "MQ135_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(controlTask, "Control_Task", 4096, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(mqttTask, "MQTT_Task", 4096, NULL, 2, NULL, 0);
  xTaskCreatePinnedToCore(displayTask, "Display_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(waterSwitchTask, "Water_Task", 2048, NULL, 1, NULL, 1);
}

void loop()
{
  vTaskDelay(pdMS_TO_TICKS(1000));
}