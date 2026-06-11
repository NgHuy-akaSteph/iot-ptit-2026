# Bảng Thiết Kế Giao Tiếp Hệ Thống IoT PTIT 2026

> Phân tích từ source code thực tế. Thời điểm: 2026-06-03 22:25

---

## Tổng quan kiến trúc

```
[ESP32 Device] ←—— MQTT ——→ [ThingsBoard Cloud] ←—— HTTP/WS ——→ [BFF Server] ←—— HTTP/WS ——→ [Flutter Client]
```

4 thành phần chính:
- **Device** — ESP32 (FreeRTOS, PubSubClient)
- **ThingsBoard** — `thingsboard.cloud` (MQTT broker + REST + WebSocket)
- **BFF Server** — Spring Boot Reactive (`iot-ptit-bff.onrender.com`)
- **Client** — Flutter app (Dio HTTP + WebSocket)

---

## 1. MQTT — Device ↔ ThingsBoard

**Broker:** `thingsboard.cloud:1883`  
**Auth:** MQTT username = Device Access Token (`zuzo3dbhbi4qtsz85l3l`)

### Topics Device PUBLISH (gửi lên ThingsBoard)

| Topic | Hướng | Interval | Payload |
|---|---|---|---|
| `v1/devices/me/telemetry` | Device → TB | 5000ms | `{"temperature":T,"humidity":H,"dust_ug":D,"gas_ppm":G,"auto_mode":bool,"fan_level":0-3}` |
| `v1/devices/me/rpc/response/{requestId}` | Device → TB | On demand | `{"status":"success"}` hoặc dữ liệu thresholds |

### Topics Device SUBSCRIBE (nhận từ ThingsBoard)

| Topic | Hướng | Mô tả |
|---|---|---|
| `v1/devices/me/rpc/request/+` | TB → Device | Nhận lệnh RPC từ server/client |

### RPC Methods nhận qua MQTT

| Method | Loại RPC | Params | Response |
|---|---|---|---|
| `setAutoMode` | One-way | `bool` | `{"status":"success"}` |
| `setFan` | One-way | `int` (0-3) | `{"status":"success"}` |
| `setThresholds` | One-way | `{"dustHigh":f,"dustMed":f,"gasHigh":f,"gasMed":f}` | `{"status":"success"}` |
| `getThresholds` | **Two-way** | `{}` | `{"dustHigh":f,"dustMed":f,"gasHigh":f,"gasMed":f}` |

---

## 2. HTTP — BFF Server ↔ ThingsBoard Cloud

**Base URL:** `https://thingsboard.cloud`  
**Auth:** Header `X-Authorization: Bearer {tbToken}`

| Method | Endpoint TB | Mô tả | Caller |
|---|---|---|---|
| `POST` | `/api/auth/login` | Xác thực user, lấy TB JWT token | ThingsboardClient |
| `GET` | `/api/plugins/telemetry/DEVICE/{deviceId}/values/timeseries?keys=...` | Lấy telemetry mới nhất (fallback) | ThingsboardClient |
| `POST` | `/api/plugins/rpc/oneway/{deviceId}` | Gửi lệnh one-way RPC tới device | ThingsboardClient |
| `POST` | `/api/plugins/rpc/twoway/{deviceId}` | Gửi lệnh two-way RPC, chờ response | ThingsboardClient |

---

## 3. HTTP — Client ↔ BFF Server

**Base URL:** `https://iot-ptit-bff.onrender.com/api`  
**Auth:** Header `Authorization: Bearer {bffJwtToken}`  
**Device ID cố định:** `b8efca70-518c-11f1-befc-1dd22c41a268`

### Auth Endpoints

| Method | Endpoint | Body | Response |
|---|---|---|---|
| `POST` | `/api/auth/login` | `{"username":"...","password":"..."}` | `{"token":"bffJWT","tbToken":"tbJWT"}` |

### Telemetry Endpoints

| Method | Endpoint | Params | Response |
|---|---|---|---|
| `GET` | `/api/devices/{deviceId}/telemetry/latest` | — | `{"temperature":[[ts,v]],...}` |
| `GET` | `/api/devices/{deviceId}/telemetry/history` | `?range=oneMinute\|oneHour\|oneDay\|oneWeek` | `{"temperature":[{"ts":ms,"value":v}],...}` |
| `POST` | `/api/devices/telemetry/webhook` | `{"deviceId":"...","temperature":T,...}` | `200 OK` |

> **Lưu ý:** Webhook `/telemetry/webhook` được gọi bởi **ThingsBoard Rule Engine** (không phải client), không yêu cầu auth (permitAll).

### RPC / Control Endpoints

| Method | Endpoint | Body | Response | Mô tả |
|---|---|---|---|---|
| `POST` | `/api/devices/{deviceId}/rpc` | `{"method":"setAutoMode","params":true}` | `{"status":"success"}` | Gửi lệnh RPC bất kỳ |
| `POST` | `/api/devices/{deviceId}/rpc` | `{"method":"setFan","params":2}` | `{"status":"success"}` | Điều khiển quạt |
| `POST` | `/api/devices/{deviceId}/thresholds` | `{"dustHigh":150,"dustMed":75,"gasHigh":800,"gasMed":400}` | `{"status":"success"}` | Cập nhật ngưỡng |
| `GET` | `/api/devices/{deviceId}/thresholds` | — | `{"dustHigh":f,"dustMed":f,"gasHigh":f,"gasMed":f}` | Đọc ngưỡng từ device |

> **Lưu ý:** `GET /thresholds` dùng **two-way RPC** → device trả về giá trị thực tế đang chạy.

---

## 4. WebSocket — Client ↔ ThingsBoard Cloud (trực tiếp)

**URL:** `wss://thingsboard.cloud/api/ws/plugins/telemetry?token={tbToken}`  

> ⚠️ Client kết nối **trực tiếp** tới ThingsBoard, **bypass BFF Server**.

### Luồng kết nối

```
1. Client lấy tbToken từ secure storage
2. Connect WSS: wss://thingsboard.cloud/api/ws/plugins/telemetry?token={tbToken}
3. Gửi auth frame:  {"authCmd":{"cmdId":0,"token":"{tbToken}"}}
4. Subscribe telemetry: {"tsSubCmds":[{"entityType":"DEVICE","entityId":"{deviceId}","scope":"LATEST_TELEMETRY","cmdId":1}]}
5. Nhận realtime push: {"data":{"temperature":[[ts,v]],...}}
```

### WebSocket Messages

| Hướng | Frame | Mô tả |
|---|---|---|
| Client → TB | `{"authCmd":{"cmdId":0,"token":"..."}}` | Xác thực session |
| Client → TB | `{"tsSubCmds":[{"entityType":"DEVICE","entityId":"...","scope":"LATEST_TELEMETRY","cmdId":1}]}` | Subscribe stream |
| TB → Client | `{"data":{"temperature":[[ts,v]],...}}` | Realtime push khi có dữ liệu mới |

---

## 5. ThingsBoard Rule Engine → BFF (Webhook)

```
Device --MQTT--> ThingsBoard --Rule Engine--> POST /api/devices/telemetry/webhook --> BFF DB (PostgreSQL)
```

| HTTP Method | URL | Trigger |
|---|---|---|
| `POST` | `https://iot-ptit-bff.onrender.com/api/devices/telemetry/webhook` | Mỗi khi device publish `v1/devices/me/telemetry` |

---

## 6. Luồng dữ liệu theo chức năng

### 6.1 Realtime Monitoring

```
ESP32 --[MQTT 5s]--> ThingsBoard --[WS push]--> Flutter (WebSocketService)
                              └--[Webhook]--> BFF Server (DB cache)
```

### 6.2 Xem Lịch sử

```
Flutter --[GET /telemetry/history?range=oneHour]--> BFF Server --[DB query]--> PostgreSQL
```

### 6.3 Lấy Telemetry Mới Nhất (fallback)

```
Flutter --[GET /telemetry/latest]--> BFF Server
         ├─[DB hit]──────────────────────────────→ trả về ngay
         └─[DB miss]──→ TB REST API ──→ lưu DB ──→ trả về
```

### 6.4 Điều Khiển Quạt / Auto Mode

```
Flutter --[POST /rpc]--> BFF --[POST /api/plugins/rpc/oneway/{id}]--> ThingsBoard
         --[MQTT rpc/request/{id}]--> ESP32
         --[MQTT rpc/response/{id}]--> ThingsBoard --> BFF {"status":"success"}
```

### 6.5 Cập Nhật Ngưỡng (setThresholds)

```
Flutter --[POST /thresholds]--> BFF --[one-way RPC "setThresholds"]--> ThingsBoard
         --[MQTT RPC request]--> ESP32 (lưu NVS Preferences) --[response]--> TB --> BFF --> Flutter
```

### 6.6 Đọc Ngưỡng (getThresholds)

```
Flutter --[GET /thresholds]--> BFF --[two-way RPC "getThresholds"]--> ThingsBoard (blocking wait)
         --[MQTT RPC request]--> ESP32
         ESP32 --[MQTT RPC response {dustHigh,dustMed,gasHigh,gasMed}]--> ThingsBoard --> BFF --> Flutter
```

---

## 7. Schema Dữ liệu

### Telemetry Payload (Device → ThingsBoard)

| Field | Kiểu | Đơn vị | Cảm biến |
|---|---|---|---|
| `temperature` | `double` | °C | DHT11 |
| `humidity` | `double` | % | DHT11 |
| `dust_ug` | `double` | µg/m³ | GP2Y1010 + EMA |
| `gas_ppm` | `double` | ppm | MQ135 + EMA |
| `auto_mode` | `bool` | — | Logic nội bộ |
| `fan_level` | `int` 0-3 | — | Logic nội bộ |

### Ngưỡng Cảnh Báo Mặc định

| Tham số | Ngưỡng Medium | Ngưỡng High | Hành động |
|---|---|---|---|
| `dust_ug` | 75 µg/m³ | 150 µg/m³ | Fan L2 / Fan L3 + Alarm 3x |
| `gas_ppm` | 400 ppm | 800 ppm | Fan L2 / Fan L3 + Alarm 3x |

> Ngưỡng lưu vào NVS Flash (Preferences) trên ESP32, bền qua reboot.

---

## 8. Bảo mật

| Layer | Cơ chế |
|---|---|
| Device → ThingsBoard | MQTT username = Device Access Token |
| Client → BFF | JWT Bearer token (tự ký bởi BFF) |
| BFF → ThingsBoard | TB JWT token forwarded trong `X-Authorization` |
| Client → ThingsBoard WS | TB JWT token trong URL param + auth frame |
| Webhook TB → BFF | No auth (permitAll, internal use only) |
