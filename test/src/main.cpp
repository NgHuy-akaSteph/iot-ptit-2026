#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Adafruit_BME280.h>
#include <Adafruit_Sensor.h>

// =====================================================
// 1. PIN CONFIG
// =====================================================
#define I2C_SDA_PIN 21
#define I2C_SCL_PIN 22

#define RAIN_ANALOG_PIN 32

#define DUST_LED_PIN 25
#define DUST_ANALOG_PIN 34

#define LDR_ANALOG_PIN 33

#define MQ_ANALOG_PIN 35

// =====================================================
// 2. WIFI + THINGSBOARD CONFIG
// =====================================================
#define WIFI_SSID "Huy Quang"
#define WIFI_PASSWORD "12345678"

#define TB_SERVER "thingsboard.cloud"
#define TB_PORT 1883
#define TB_TOKEN "HjkhKV0E3Ufb6dQStl40"

// =====================================================
// 3. LCD + BME280
// =====================================================
// Nếu LCD không hiển thị, thử đổi 0x27 thành 0x3F
LiquidCrystal_I2C lcd(0x27, 16, 2);
Adafruit_BME280 bme;

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

// =====================================================
// 4. ADC CONFIG
// =====================================================
const float ESP32_ADC_REF = 3.3;
const int ADC_MAX = 4095;

// =====================================================
// 5. RAIN + LIGHT THRESHOLD
// =====================================================
// Cảm biến mưa thường: khô raw cao, ướt raw thấp
const int RAIN_THRESHOLD = 3000;

// LDR tùy module có thể ngược.
// Nếu thấy sáng/tối sai, sửa logic trong getLightStatus().
const int LIGHT_THRESHOLD = 2000;

// =====================================================
// 6. GP2Y CONFIG
// =====================================================
// GP2Y giữ công thức cũ:
// dustDensity_mg = 0.17 * voltage - 0.1
const float GP2Y_VOLTAGE_MULTIPLIER = 1.0;

// =====================================================
// 7. MQ CONFIG
// =====================================================
// Các hệ số giữ theo code cũ
const float V_C = 5.0;
const float R_L = 10.0;
const float R_0 = 1.87;
const float CONST_A = 116.602;
const float CONST_B = -2.769;

// Nếu dùng chia áp 10k + 10k thì để 2.0.
// Nếu dùng chia áp 10k + 15k thì đổi thành 1.666.
const float MQ_VOLTAGE_MULTIPLIER = 2.0;

// MQ cần thời gian làm nóng
const TickType_t MQ_WARM_UP_TIME = pdMS_TO_TICKS(60000);

// =====================================================
// 8. FILTER CONFIG
// =====================================================
const float EMA_ALPHA = 0.1;

// =====================================================
// 9. DATA STRUCT
// Chỉ giữ các giá trị cần dùng chính thức
// =====================================================
struct WeatherEnvironment
{
  float temperature;
  float humidity;
  float pressure_hpa;

  float dust_ug;
  float gas_ppm;

  int rain_raw;
  int light_raw;
};

WeatherEnvironment currentEnv = {
    0.0, 0.0, 0.0,
    0.0, 0.0,
    0, 0};

SemaphoreHandle_t envMutex;

bool mqReady = false;

// =====================================================
// 10. UTILS
// =====================================================
float adcToVoltage(int raw)
{
  return raw * ESP32_ADC_REF / ADC_MAX;
}

float filterEMA(float newValue, float previousValue, float alpha)
{
  if (previousValue < 0.0)
    return newValue;

  return alpha * newValue + (1.0 - alpha) * previousValue;
}

String getRainStatus(int rainRaw)
{
  // Thường: khô raw cao, ướt raw thấp
  if (rainRaw < RAIN_THRESHOLD)
    return "RAIN";

  return "NO RAIN";
}

String getLightStatus(int lightRaw)
{
  // Nếu test thực tế thấy ngược, đổi dấu < thành >
  if (lightRaw < LIGHT_THRESHOLD)
    return "DARK";

  return "BRIGHT";
}

String getAirQualityByDust(float dust)
{
  if (dust < 50.0)
    return "GOOD";

  if (dust < 75.0)
    return "MED";

  return "BAD";
}

// =====================================================
// 11. TASK: BME280
// =====================================================
void bmeTask(void *pvParameters)
{
  for (;;)
  {
    float t = bme.readTemperature();
    float h = bme.readHumidity();
    float p = bme.readPressure() / 100.0F;

    if (!isnan(t) && !isnan(h) && !isnan(p))
    {
      if (xSemaphoreTake(envMutex, portMAX_DELAY))
      {
        currentEnv.temperature = t;
        currentEnv.humidity = h;
        currentEnv.pressure_hpa = p;
        xSemaphoreGive(envMutex);
      }
    }

    vTaskDelay(pdMS_TO_TICKS(2000));
  }
}

// =====================================================
// 12. TASK: GP2Y1010AU0F
// =====================================================
void dustSensorTask(void *pvParameters)
{
  static float filteredDust = -1.0;

  for (;;)
  {
    // GP2Y LED control thường active LOW
    digitalWrite(DUST_LED_PIN, LOW);
    delayMicroseconds(280);

    int rawDust = analogRead(DUST_ANALOG_PIN);

    delayMicroseconds(40);
    digitalWrite(DUST_LED_PIN, HIGH);
    delayMicroseconds(9680);

    float vEsp32 = adcToVoltage(rawDust);
    float voltage = vEsp32 * GP2Y_VOLTAGE_MULTIPLIER;

    float dustDensity_mg = 0.17 * voltage - 0.1;

    if (dustDensity_mg < 0.0)
      dustDensity_mg = 0.0;

    float dustUg = dustDensity_mg * 1000.0;
    filteredDust = filterEMA(dustUg, filteredDust, EMA_ALPHA);

    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      currentEnv.dust_ug = filteredDust;
      xSemaphoreGive(envMutex);
    }

    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

// =====================================================
// 13. TASK: MQ-135 / MQ-7 / MQ-9
// =====================================================
void gasSensorTask(void *pvParameters)
{
  TickType_t startTime = xTaskGetTickCount();
  static float filteredGas = -1.0;

  for (;;)
  {
    int rawGas = analogRead(MQ_ANALOG_PIN);

    if (!mqReady && (xTaskGetTickCount() - startTime) >= MQ_WARM_UP_TIME)
    {
      mqReady = true;
    }

    if (mqReady)
    {
      float vEsp32 = adcToVoltage(rawGas);
      float vRl = constrain(vEsp32 * MQ_VOLTAGE_MULTIPLIER, 0.01, 4.8);

      float r_s = R_L * ((V_C / vRl) - 1.0);
      float gasPpm = CONST_A * pow((r_s / R_0), CONST_B);

      if (gasPpm < 0.0 || isnan(gasPpm) || isinf(gasPpm))
        gasPpm = 0.0;

      filteredGas = filterEMA(gasPpm, filteredGas, EMA_ALPHA);

      if (xSemaphoreTake(envMutex, portMAX_DELAY))
      {
        currentEnv.gas_ppm = filteredGas;
        xSemaphoreGive(envMutex);
      }
    }

    vTaskDelay(pdMS_TO_TICKS(2000));
  }
}

// =====================================================
// 14. TASK: RAIN + LDR, CHỈ DÙNG A0
// =====================================================
void rainLightTask(void *pvParameters)
{
  for (;;)
  {
    int rainRaw = analogRead(RAIN_ANALOG_PIN);
    int lightRaw = analogRead(LDR_ANALOG_PIN);

    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      currentEnv.rain_raw = rainRaw;
      currentEnv.light_raw = lightRaw;
      xSemaphoreGive(envMutex);
    }

    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

// =====================================================
// 15. TASK: LCD DISPLAY
// LCD chỉ hiển thị: nhiệt độ, độ ẩm, áp suất, bụi
// =====================================================
void displayTask(void *pvParameters)
{
  int page = 0;
  char row[17];

  for (;;)
  {
    WeatherEnvironment env;

    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      env = currentEnv;
      xSemaphoreGive(envMutex);
    }

    lcd.clear();

    if (page == 0)
    {
      lcd.setCursor(0, 0);
      snprintf(row, sizeof(row), "T:%4.1fC H:%2.0f%%", env.temperature, env.humidity);
      lcd.print(row);

      lcd.setCursor(0, 1);
      snprintf(row, sizeof(row), "P:%4.0f hPa", env.pressure_hpa);
      lcd.print(row);
    }
    else if (page == 1)
    {
      lcd.setCursor(0, 0);
      lcd.print("Dust PM2.5:");

      lcd.setCursor(0, 1);
      snprintf(row, sizeof(row), "%4.0f ug/m3 %s", env.dust_ug, getAirQualityByDust(env.dust_ug).c_str());
      lcd.print(row);
    }

    page++;
    if (page > 1)
      page = 0;

    vTaskDelay(pdMS_TO_TICKS(3000));
  }
}

// =====================================================
// 16. TASK: SERIAL DEBUG
// In toàn bộ thông số qua Serial Monitor
// =====================================================
void serialTask(void *pvParameters)
{
  for (;;)
  {
    WeatherEnvironment env;

    if (xSemaphoreTake(envMutex, portMAX_DELAY))
    {
      env = currentEnv;
      xSemaphoreGive(envMutex);
    }

    Serial.println("========== WEATHER STATION ==========");

    Serial.print("Temperature: ");
    Serial.print(env.temperature, 2);
    Serial.println(" C");

    Serial.print("Humidity: ");
    Serial.print(env.humidity, 2);
    Serial.println(" %");

    Serial.print("Pressure: ");
    Serial.print(env.pressure_hpa, 2);
    Serial.println(" hPa");

    Serial.print("Dust PM2.5: ");
    Serial.print(env.dust_ug, 2);
    Serial.print(" ug/m3 | Air Quality: ");
    Serial.println(getAirQualityByDust(env.dust_ug));

    Serial.print("Gas: ");
    if (mqReady)
    {
      Serial.print(env.gas_ppm, 2);
      Serial.println(" ppm");
    }
    else
    {
      Serial.println("warming...");
    }

    Serial.print("Rain raw: ");
    Serial.print(env.rain_raw);
    Serial.print(" | Status: ");
    Serial.println(getRainStatus(env.rain_raw));

    Serial.print("Light raw: ");
    Serial.print(env.light_raw);
    Serial.print(" | Status: ");
    Serial.println(getLightStatus(env.light_raw));

    Serial.println();

    vTaskDelay(pdMS_TO_TICKS(3000));
  }
}

// =====================================================
// 17. WIFI + MQTT
// =====================================================
void connectWiFi()
{
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting WiFi");

  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("WiFi connected. IP: ");
  Serial.println(WiFi.localIP());
}

void connectMQTT()
{
  while (!mqtt.connected())
  {
    String clientId = "esp32-weather-" + String((uint32_t)ESP.getEfuseMac(), HEX);

    Serial.print("Connecting MQTT... ");

    if (mqtt.connect(clientId.c_str(), TB_TOKEN, NULL))
    {
      Serial.println("OK");
    }
    else
    {
      Serial.print("failed, rc=");
      Serial.println(mqtt.state());
      vTaskDelay(pdMS_TO_TICKS(3000));
    }
  }
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

        WeatherEnvironment env;

        if (xSemaphoreTake(envMutex, portMAX_DELAY))
        {
          env = currentEnv;
          xSemaphoreGive(envMutex);
        }

        StaticJsonDocument<256> doc;

        doc["temperature"] = env.temperature;
        doc["humidity"] = env.humidity;
        doc["pressure_hpa"] = env.pressure_hpa;

        doc["dust_ug"] = env.dust_ug;
        doc["gas_ppm"] = env.gas_ppm;

        doc["rain_raw"] = env.rain_raw;
        doc["light_raw"] = env.light_raw;

        char buffer[256];
        size_t n = serializeJson(doc, buffer);

        mqtt.publish("v1/devices/me/telemetry", (uint8_t *)buffer, n, false);

        Serial.println("Published telemetry:");
        Serial.println(buffer);
      }
    }
    else
    {
      connectWiFi();
    }

    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

// =====================================================
// 18. SETUP & LOOP
// =====================================================
void setup()
{
  Serial.begin(115200);

  pinMode(DUST_LED_PIN, OUTPUT);
  digitalWrite(DUST_LED_PIN, HIGH);

  analogReadResolution(12);

  /*
    ADC_11db giúp ESP32 đọc analog ở dải gần 0–3.3V.
    Không có nghĩa là chân ESP32 chịu được 5V.
    Nếu module xuất A0 5V, vẫn cần chia áp trước khi nối vào ESP32.
  */
  analogSetPinAttenuation(RAIN_ANALOG_PIN, ADC_11db);
  analogSetPinAttenuation(DUST_ANALOG_PIN, ADC_11db);
  analogSetPinAttenuation(LDR_ANALOG_PIN, ADC_11db);
  analogSetPinAttenuation(MQ_ANALOG_PIN, ADC_11db);

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

  lcd.init();
  lcd.backlight();

  lcd.setCursor(0, 0);
  lcd.print("Weather Station");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");
  delay(1500);

  bool bmeOk = bme.begin(0x76);

  if (!bmeOk)
    bmeOk = bme.begin(0x77);

  if (!bmeOk)
  {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("BME280 ERROR");
    lcd.setCursor(0, 1);
    lcd.print("Check wiring");

    Serial.println("BME280 not found. Check wiring/address.");

    while (true)
    {
      delay(1000);
    }
  }

  envMutex = xSemaphoreCreateMutex();

  connectWiFi();

  mqtt.setServer(TB_SERVER, TB_PORT);
  mqtt.setBufferSize(256);

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("System Ready");
  lcd.setCursor(0, 1);
  lcd.print("MQ warming...");
  delay(1500);

  xTaskCreatePinnedToCore(bmeTask, "BME_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(dustSensorTask, "Dust_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(gasSensorTask, "Gas_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(rainLightTask, "Rain_Light_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(displayTask, "Display_Task", 4096, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(serialTask, "Serial_Task", 4096, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(mqttTask, "MQTT_Task", 4096, NULL, 2, NULL, 0);
}

void loop()
{
  // Không dùng loop vì hệ thống chạy bằng FreeRTOS tasks
}