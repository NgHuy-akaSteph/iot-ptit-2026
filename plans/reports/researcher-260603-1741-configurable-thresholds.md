# Researcher Report: Configurable Thresholds for IoT PTIT

## Context
Add runtime-configurable alerts/action thresholds for dust (`dustHigh`, `dustMed`) and gas (`gasHigh`, `gasMed`) levels. 
Currently, the values are hardcoded in `controlTask()` (150/75 for dust, 800/400 for gas).

## 1. Device Implementation Analysis
- **Persistence**: Use standard ESP32 `Preferences` library with namespace `"thresholds"`.
- **Concurrency & Thread Safety**: Declare thresholds as global variables and access/mutate them within `envMutex` lock blocks since `controlTask` (core 1) and `mqttTask` (core 0, handles `onMqttMessage` callbacks) run asynchronously.
- **RPC Methods**:
  - `setThresholds`: parses parameters, updates globals and `Preferences`, and plays a validation alarm.
  - `getThresholds`: returns a JSON map of current thresholds to response topic `v1/devices/me/rpc/response/{requestId}`.

## 2. Server Implementation Analysis
- **Endpoints**:
  - `POST /api/devices/{deviceId}/thresholds`: Maps to `setThresholds` RPC command (one-way).
  - `GET /api/devices/{deviceId}/thresholds`: Maps to `getThresholds` RPC command (two-way) to query the device.
- **RPC Commands in BFF**:
  - Update `ThingsboardClient.java` to support two-way RPC by hitting `/api/plugins/rpc/twoway/{deviceId}`.
  - Update `RpcService.java` to support dispatching two-way RPC and logging them in PostgreSQL database.

## 3. Flutter Client Implementation Analysis
- **Settings Form**:
  - Enhance `settings_panel.dart` to query thresholds on init and show input fields.
  - Apply inputs validation (decimals, non-negative, and range logic: `Med < High`).
  - Dark/Light responsive UI styling using standard Teal/Blue themes.
- **HTTP client**:
  - Add API integration in `ThingsBoardService` mapping to the new server REST endpoints.
