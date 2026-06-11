# Phase 1: ESP32 Firmware Integration

## Context Links
- **Researcher Report**: [researcher-260603-1741-configurable-thresholds.md](file:///h:/SideProjects/iot-ptit-2026/plans/reports/researcher-260603-1741-configurable-thresholds.md)
- **Main Device Code**: [main.cpp](file:///h:/SideProjects/iot-ptit-2026/device/src/main.cpp)

## Overview
- **Priority**: HIGH
- **Current Status**: TODO
- **Description**: Add `Preferences` initialization and retrieval, handle `setThresholds` and `getThresholds` RPCs via MQTT, and make thresholds adjustable in the control loop with proper mutex synchronization.

## Key Insights
- **Flash Write Endurance**: Non-volatile storage write occurs only when the threshold value is explicitly modified (via `setThresholds`). It will not write on boot or normal telemetries.
- **Concurrency**: ESP32 utilizes FreeRTOS. Mutating variables globally from the MQTT callback thread requires locking with `envMutex` since the control task runs on a separate core.

## Requirements
- Maintain default thresholds: Dust High = 150.0, Dust Med = 75.0, Gas High = 800.0, Gas Med = 400.0.
- Safe type conversion and parsing validation.

## Architecture
- MQTT message handler `onMqttMessage` updates thresholds and commits to flash via `Preferences`.
- `controlTask` grabs a local copy of these variables under the protection of `envMutex` during its periodic execution.

## Related Code Files
- [MODIFY] [main.cpp](file:///h:/SideProjects/iot-ptit-2026/device/src/main.cpp)

## Implementation Steps
1. Add `#include <Preferences.h>`.
2. Define threshold variables as global: `volatile float dustHigh`, `volatile float dustMed`, `volatile float gasHigh`, `volatile float gasMed`.
3. In `setup()`, read thresholds from `Preferences` under the name `"thresholds"`, using the default values if not yet set in flash.
4. Implement `setThresholds` RPC inside `onMqttMessage()`. Extract keys, assign them under `envMutex` lock, save to `Preferences`, and trigger buzzer confirmation.
5. Implement `getThresholds` RPC inside `onMqttMessage()`. Read thresholds under `envMutex` lock, build response JSON, and publish to the `v1/devices/me/rpc/response/{requestId}` topic before returning immediately to prevent duplicate response.
6. Replace hardcoded comparisons in `controlTask()` with local copies of threshold globals.

## Todo List
- [ ] Add `<Preferences.h>` include and define global threshold variables.
- [ ] Initialize variables in `setup()` by reading from `Preferences`.
- [ ] Handle `setThresholds` RPC method in `onMqttMessage()`.
- [ ] Handle `getThresholds` RPC method in `onMqttMessage()`.
- [ ] Update `controlTask()` logic to use threshold variables.
- [ ] Validate device logic compiles successfully.

## Success Criteria
- The device compiles and flashes without error.
- Sending `setThresholds` payload via MQTT modifies the local behavior of LEDs/fans appropriately.
- Sending `getThresholds` payload via MQTT retrieves the exact configured values.
- Configuration survives device reboot.

## Risk Assessment
- *Risk*: Memory fragmentation or crash if JSON document size is too small.
- *Mitigation*: Ensure `StaticJsonDocument` capacity is adequate (256-512 bytes is plenty).

## Security Considerations
- RPC commands are only accepted on authorized MQTT sub-topics, ensuring standard ThingsBoard device credentials protect them.
