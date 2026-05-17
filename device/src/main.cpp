#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "DHT.h"

// ==========================================
// CẤU HÌNH PHẦN CỨNG
// ==========================================
// 1. GP2Y (Bụi)
#define DUST_LED_PIN 26
#define DUST_ANALOG_PIN 35

// 2. MQ-135 (Khí)
#define MQ135_ANALOG_PIN 34
const float V_C = 5.0;
const float R_L = 10.0;
const float R_0 = 76.63;
const float CONST_A = 116.602;
const float CONST_B = -2.769;

// 3. DHT11 (Nhiệt độ, Độ ẩm)
#define DHTPIN 4
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// ==========================================
// CẤU HÌNH WIFI & THINGSBOARD MQTT
// ==========================================
// LƯU Ý WIFI:
// - Đang để mạng nhà bạn ("Huy Quang").
// - Nếu bạn ném code này lên giả lập Wokwi để test lại, hãy đổi thành SSID: "Wokwi-GUEST", Pass: ""
#define WIFI_SSID "Huy Quang"
#define WIFI_PASSWORD "12345678"

// LƯU Ý THINGSBOARD:
// Lấy TB_TOKEN từ file mqtt.cpp demo của bạn
#define TB_SERVER "thingsboard.cloud"
#define TB_PORT 1883
#define TB_TOKEN "hlbzkwx28cc5hy9uydbv"

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

// ==========================================
// CẤU TRÚC DỮ LIỆU & RTOS MUTEX
// ==========================================
struct SystemEnvironment
{
  float dust_ug;
  float gas_ppm;
  float temperature;
  float humidity;
};

SystemEnvironment currentEnv = {0.0, 0.0, 0.0, 0.0};
SemaphoreHandle_t envMutex;

// Khai báo nguyên mẫu hàm
void connectMQTT();
void onMqttMessage(char *topic, byte *payload, unsigned int length);

// ==========================================
// TASKS: ĐỌC CẢM BIẾN 
// ==========================================

// Task 1: Đọc DHT11
void dhtTask(void *pvParameters)
{
  dht.begin();
  for (;;)
  {
    float h = dht.readHumidity();
    float t = dht.readTemperature();

    if (!isnan(h) && !isnan(t))
    {
      if (xSemaphoreTake(envMutex, portMAX_DELAY) == pdTRUE)
      {
        currentEnv.temperature = t;
        currentEnv.humidity = h;
        xSemaphoreGive(envMutex);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(2000));
  }
}

// Task 2: Đọc cảm biến bụi GP2Y
void dustSensorTask(void *pvParameters)
{
  pinMode(DUST_LED_PIN, OUTPUT);
  pinMode(DUST_ANALOG_PIN, INPUT);
  digitalWrite(DUST_LED_PIN, HIGH);

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

    float calculatedDust = dustDensity_mg * 1000;

    if (xSemaphoreTake(envMutex, portMAX_DELAY) == pdTRUE)
    {
      currentEnv.dust_ug = calculatedDust;
      xSemaphoreGive(envMutex);
    }
    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

// Task 3: Đọc MQ-135
void mq135Task(void *pvParameters)
{
  pinMode(MQ135_ANALOG_PIN, INPUT);
  TickType_t startTime = xTaskGetTickCount();
  const TickType_t WARM_UP_TIME = pdMS_TO_TICKS(60000);
  bool isReady = false;

  for (;;)
  {
    int rawGas = analogRead(MQ135_ANALOG_PIN);
    if (!isReady)
    {
      if ((xTaskGetTickCount() - startTime) >= WARM_UP_TIME)
        isReady = true;
    }

    if (isReady)
    {
      float v_esp = rawGas * (3.3 / 4095.0);
      float v_rl = v_esp * 2.0;

      if (v_rl <= 0.0)
        v_rl = 0.01;
      if (v_rl > 4.8)
        v_rl = 4.8;

      float r_s = R_L * ((V_C / v_rl) - 1.0);
      float ppm = CONST_A * pow((r_s / R_0), CONST_B);

      if (xSemaphoreTake(envMutex, portMAX_DELAY) == pdTRUE)
      {
        currentEnv.gas_ppm = ppm;
        xSemaphoreGive(envMutex);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(2000));
  }
}

// ==========================================
// TASKS: GIAO TIẾP MẠNG & MQTT THAY THẾ FIREBASE
// ==========================================

void connectMQTT()
{
  while (!mqtt.connected())
  {
    Serial.print("Đang kết nối MQTT ThingsBoard...");
    String clientId = "esp32-" + String((uint32_t)ESP.getEfuseMac(), HEX);

    // Username chính là Access Token, Password để rỗng
    if (mqtt.connect(clientId.c_str(), TB_TOKEN, NULL))
    {
      Serial.println(" OK!");
      // Đăng ký nhận lệnh điều khiển từ App (RPC Calls)
      mqtt.subscribe("v1/devices/me/rpc/request/+", 1);
    }
    else
    {
      Serial.printf(" LỖI rc=%d, thử lại sau 3s\n", mqtt.state());
      vTaskDelay(pdMS_TO_TICKS(3000));
    }
  }
}

// Callback khi có lệnh điều khiển quạt từ App (Flutter) gửi xuống
void onMqttMessage(char *topic, byte *payload, unsigned int length)
{
  String msg;
  for (unsigned int i = 0; i < length; i++)
    msg += (char)payload[i];
  Serial.printf("\n[Nhận Lệnh] %s -> %s\n", topic, msg.c_str());

  // Nơi đây bạn sẽ parse JSON và điều khiển PWM chân Quạt trong tương lai
  // ...
}

// Task xử lý MQTT (Thay thế cho firebaseTask cũ)
void mqttTask(void *pvParameters)
{
  TickType_t lastPublishTime = xTaskGetTickCount();
  const TickType_t PUBLISH_INTERVAL = pdMS_TO_TICKS(5000); // 5s gửi 1 lần

  for (;;)
  {
    if (WiFi.status() == WL_CONNECTED)
    {
      if (!mqtt.connected())
      {
        connectMQTT();
      }
      mqtt.loop(); // Hàm cực kỳ quan trọng để giữ kết nối không bị văng

      // Đến chu kỳ gửi dữ liệu
      if ((xTaskGetTickCount() - lastPublishTime) >= PUBLISH_INTERVAL)
      {
        lastPublishTime = xTaskGetTickCount();
        SystemEnvironment tempEnv;

        // Lấy dữ liệu an toàn từ Mutex
        if (xSemaphoreTake(envMutex, portMAX_DELAY) == pdTRUE)
        {
          tempEnv = currentEnv;
          xSemaphoreGive(envMutex);
        }

        // Tạo chuỗi JSON
        StaticJsonDocument<256> doc;
        doc["temperature"] = tempEnv.temperature;
        doc["humidity"] = tempEnv.humidity;
        doc["dust_ug"] = tempEnv.dust_ug;
        doc["gas_ppm"] = tempEnv.gas_ppm;

        char buffer[256];
        size_t n = serializeJson(doc, buffer);

        // Gửi lên topic chuẩn của ThingsBoard
        mqtt.publish("v1/devices/me/telemetry", buffer, n, false);

        Serial.printf("[TX] Đã gửi: %s\n", buffer);
      }
    }
    // Delay nhỏ để nhường CPU cho các Task khác (Watchdog khỏi chửi)
    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

// ==========================================
// SETUP & LOOP
// ==========================================
void setup()
{
  Serial.begin(115200);

  // 1. Khởi tạo Mutex
  envMutex = xSemaphoreCreateMutex();

  // 2. Kết nối WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Đang kết nối WiFi");
  while (WiFi.status() != WL_CONNECTED)
  {
    Serial.print(".");
    delay(500);
  }
  Serial.println("\nĐã kết nối WiFi!");

  // 3. Khởi tạo MQTT
  mqtt.setServer(TB_SERVER, TB_PORT);
  mqtt.setCallback(onMqttMessage);
  mqtt.setBufferSize(512); // Tăng buffer để nhận payload lớn

  // 4. Khởi tạo các RTOS Tasks
  xTaskCreatePinnedToCore(dhtTask, "DHT_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(dustSensorTask, "Dust_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(mq135Task, "MQ135_Task", 2048, NULL, 1, NULL, 1);
  xTaskCreatePinnedToCore(mqttTask, "MQTT_Task", 4096, NULL, 2, NULL, 0);
}

void loop()
{
  vTaskDelay(pdMS_TO_TICKS(1000));
}