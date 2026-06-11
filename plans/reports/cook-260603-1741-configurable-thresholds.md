# Implementation Progress Report: Configurable Thresholds

## Summary of Completed Tasks

### 1. ESP32 Firmware ([main.cpp](file:///h:/SideProjects/iot-ptit-2026/device/src/main.cpp))
- Declared thread-safe threshold variables (`dustHigh`, `dustMed`, `gasHigh`, `gasMed`) initialized from non-volatile storage (`Preferences`) at boot.
- Substituted hardcoded limits in `controlTask()` loop with dynamic threshold variables.
- Added MQTT RPC handlers for `"setThresholds"` (updating Preferences and globals) and `"getThresholds"` (synchronously reporting thresholds back via two-way response).
- **Verification**: Built and verified firmware using PlatformIO (`pio run`). Compilation succeeded with `[SUCCESS]` (Flash 61.1%, RAM 13.9%).

### 2. BFF Backend Server
- **ThingsboardClient ([ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java))**: Added support for synchronous two-way RPC commands to `/api/plugins/rpc/twoway/{deviceId}`.
- **RpcService ([RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java))**: Added logging wrapper for two-way RPC commands.
- **RpcController ([RpcController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/RpcController.java))**: Exposed endpoints `POST /api/devices/{deviceId}/thresholds` and `GET /api/devices/{deviceId}/thresholds`.
- **Verification**: Compiled backend server successfully via Gradle (`.\gradlew compileJava` completed with `BUILD SUCCESSFUL`).

### 3. Flutter Client App
- **ThingsBoard Service ([thingsboard_service.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/service/thingsboard_service.dart))**: Added REST mapping methods `getThresholds` and `updateThresholds`.
- **Settings Panel ([settings_panel.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/widgets/settings_panel.dart))**: 
  - Embedded Form UI with fields for all four threshold bounds.
  - Implemented validator functions checking boundaries and ensuring positive decimals.
  - Added loading indicator transitions and user-friendly snackbar alert feedbacks.
  - Wrapped UI in a scrollable view to prevent layout overflows when the virtual keyboard rises.
