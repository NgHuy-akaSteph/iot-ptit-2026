#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Preferences.h>

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
#define BUZZER_PIN 23

#define LED_GREEN 12
#define LED_YELLOW 13
#define LED_RED 14

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

// Đã bổ sung khai báo LCD
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
bool buzzerOn = false;
volatile bool mistOn = false;
volatile bool waterLow = false;

volatile float dustHigh = 150.0;
volatile float dustMed = 75.0;
volatile float gasHigh = 800.0;
volatile float gasMed = 400.0;
volatile float tempHigh = 35.0;
volatile float humLow = 60.0;

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

void alarmOn(int times, int duration = 100)
{
  for (int i = 0; i < times; i++)
  {
    tone(BUZZER_PIN, 2500);
    vTaskDelay(pdMS_TO_TICKS(duration));
    noTone(BUZZER_PIN);
    vTaskDelay(pdMS_TO_TICKS(duration));
  }
}

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
  static int lastPollutionLevel = 0;
  for (;;)
  {
    float dust = 0, gas = 0, temp = 0, hum = 0;
    bool localWaterLow = false;
    float localDustHigh = 150.0, localDustMed = 75.0, localGasHigh = 800.0, localGasMed = 400.0;
    float localTempHigh = 35.0, localHumLow = 60.0;
    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      dust = currentEnv.dust_ug;
      gas = currentEnv.gas_ppm;
      temp = currentEnv.temperature;
      hum = currentEnv.humidity;
      localWaterLow = currentEnv.water_low;
      localDustHigh = dustHigh;
      localDustMed = dustMed;
      localGasHigh = gasHigh;
      localGasMed = gasMed;
      localTempHigh = tempHigh;
      localHumLow = humLow;
      xSemaphoreGive(envMutex);
    }

    if (dust > localDustHigh || gas > localGasHigh)
    {
      digitalWrite(LED_RED, HIGH);
      digitalWrite(LED_YELLOW, LOW);
      digitalWrite(LED_GREEN, LOW);
      if (autoMode)
      {
        fanLevel = 3;
        if (lastPollutionLevel != 3)
          alarmOn(3, 150);
      }
      lastPollutionLevel = 3;
    }
    else if (dust > localDustMed || gas > localGasMed)
    {
      digitalWrite(LED_RED, LOW);
      digitalWrite(LED_YELLOW, HIGH);
      digitalWrite(LED_GREEN, LOW);
      if (autoMode)
        fanLevel = 2;
      lastPollutionLevel = 2;
    }
    else
    {
      digitalWrite(LED_RED, LOW);
      digitalWrite(LED_YELLOW, LOW);
      digitalWrite(LED_GREEN, HIGH);
      if (autoMode)
        fanLevel = 0;
      lastPollutionLevel = 0;
    }

    if (buzzerOn)
      tone(BUZZER_PIN, 2500);
    else
      noTone(BUZZER_PIN);

    if (fanLevel != currentFanLevel)
    {
      bool canChange = false;

      if (!autoMode)
      {
        canChange = true;
      }
      else
      {
        if (fanLevel > currentFanLevel)
          canChange = true;
        else if (currentFanLevel == 3 && millis() - lastFanChangeTime >= 30000)
          canChange = true;
        else if (currentFanLevel == 2 && millis() - lastFanChangeTime >= 20000)
          canChange = true;
        else if (currentFanLevel <= 1)
          canChange = true;
      }

      if (canChange)
      {
        currentFanLevel = fanLevel;
        lastFanChangeTime = millis();

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
    }

    // Mist control logic
    if (localWaterLow)
    {
      mistOn = false;
    }
    else if (autoMode)
    {
      if (temp > localTempHigh || (hum < localHumLow && hum > 0.0))
      {
        mistOn = true;
      }
      else
      {
        mistOn = false;
      }
    }
    digitalWrite(MIST_RELAY_PIN, mistOn ? HIGH : LOW);

    vTaskDelay(pdMS_TO_TICKS(500));
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
    if (autoMode)
    {
      alarmOn(2, 80);
      fanLevel = 0;
      currentFanLevel = 0;
      digitalWrite(FAN_RELAY_PIN, LOW);
      ledcWrite(pwmChannel, 255);
    }
    else
    {
      alarmOn(1, 300);
    }
  }
  else if (method == "setFan" && !autoMode)
  {
    if (doc["params"].is<int>()) {
      fanLevel = doc["params"].as<int>();
    } else {
      String rawParam = doc["params"].as<String>();
      fanLevel = rawParam.toInt();
    }
    alarmOn(1, 100);
  }
  else if (method == "setMist" && !autoMode)
  {
    mistOn = doc["params"].as<bool>();
    alarmOn(1, 100);
  }
  else if (method == "setThresholds")
  {
    JsonObject paramsObj = doc["params"].as<JsonObject>();
    float newDustHigh = paramsObj.containsKey("dustHigh") ? paramsObj["dustHigh"].as<float>() : dustHigh;
    float newDustMed = paramsObj.containsKey("dustMed") ? paramsObj["dustMed"].as<float>() : dustMed;
    float newGasHigh = paramsObj.containsKey("gasHigh") ? paramsObj["gasHigh"].as<float>() : gasHigh;
    float newGasMed = paramsObj.containsKey("gasMed") ? paramsObj["gasMed"].as<float>() : gasMed;
    float newTempHigh = paramsObj.containsKey("tempHigh") ? paramsObj["tempHigh"].as<float>() : tempHigh;
    float newHumLow = paramsObj.containsKey("humLow") ? paramsObj["humLow"].as<float>() : humLow;

    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      dustHigh = newDustHigh;
      dustMed = newDustMed;
      gasHigh = newGasHigh;
      gasMed = newGasMed;
      tempHigh = newTempHigh;
      humLow = newHumLow;
      xSemaphoreGive(envMutex);
    }

    Preferences prefs;
    prefs.begin("thresholds", false);
    prefs.putFloat("dustHigh", newDustHigh);
    prefs.putFloat("dustMed", newDustMed);
    prefs.putFloat("gasHigh", newGasHigh);
    prefs.putFloat("gasMed", newGasMed);
    prefs.putFloat("tempHigh", newTempHigh);
    prefs.putFloat("humLow", newHumLow);
    prefs.end();

    alarmOn(1, 150);
  }
  else if (method == "getThresholds")
  {
    StaticJsonDocument<256> responseDoc;
    float localDustHigh = 150.0, localDustMed = 75.0, localGasHigh = 800.0, localGasMed = 400.0;
    float localTempHigh = 35.0, localHumLow = 60.0;
    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      localDustHigh = dustHigh;
      localDustMed = dustMed;
      localGasHigh = gasHigh;
      localGasMed = gasMed;
      localTempHigh = tempHigh;
      localHumLow = humLow;
      xSemaphoreGive(envMutex);
    }
    
    responseDoc["dustHigh"] = localDustHigh;
    responseDoc["dustMed"] = localDustMed;
    responseDoc["gasHigh"] = localGasHigh;
    responseDoc["gasMed"] = localGasMed;
    responseDoc["tempHigh"] = localTempHigh;
    responseDoc["humLow"] = localHumLow;
    
    char responseBuffer[256];
    serializeJson(responseDoc, responseBuffer);
    String responseTopic = "v1/devices/me/rpc/response/" + requestId;
    mqtt.publish(responseTopic.c_str(), responseBuffer);
    return;
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
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_YELLOW, OUTPUT);
  pinMode(LED_RED, OUTPUT);
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

  Preferences preferences;
  preferences.begin("thresholds", true);
  dustHigh = preferences.getFloat("dustHigh", 150.0);
  dustMed = preferences.getFloat("dustMed", 75.0);
  gasHigh = preferences.getFloat("gasHigh", 800.0);
  gasMed = preferences.getFloat("gasMed", 400.0);
  tempHigh = preferences.getFloat("tempHigh", 35.0);
  humLow = preferences.getFloat("humLow", 60.0);
  preferences.end();

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