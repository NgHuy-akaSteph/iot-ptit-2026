---
title: Configurable Thresholds
description: Implement runtime-configurable alert thresholds on ESP32, bridge config via Spring Boot server, and build a Flutter settings UI.
status: COMPLETE
priority: HIGH
effort: MEDIUM
branch: feature/configurable-thresholds
tags: [device, backend, mobile, thingsboard]
created: 2026-06-03
---

# Plan: Configurable Thresholds

Enable dynamic alert threshold updates for dust and gas from the Flutter UI down to the ESP32 hardware via the BFF Server and ThingsBoard RPC.

## Phases

- **[Phase 1: ESP32 Firmware Integration](file:///h:/SideProjects/iot-ptit-2026/plans/260603-1741-configurable-thresholds/phase-01-device.md)**: `DONE`
  - Implement `Preferences` storage and global thresholds under mutex.
  - Implement `setThresholds` and `getThresholds` MQTT RPC handling.
  - Replace hardcoded limits with dynamic variables in `controlTask()`.

- **[Phase 2: BFF Server Bridge Endpoints](file:///h:/SideProjects/iot-ptit-2026/plans/260603-1741-configurable-thresholds/phase-02-server.md)**: `DONE`
  - Add two-way RPC support to `ThingsboardClient` and `RpcService`.
  - Expose `POST /api/devices/{deviceId}/thresholds` and `GET /api/devices/{deviceId}/thresholds`.

- **[Phase 3: Flutter Settings UI](file:///h:/SideProjects/iot-ptit-2026/plans/260603-1741-configurable-thresholds/phase-03-client.md)**: `DONE`
  - Add form input controls with validation to `settings_panel.dart`.
  - Implement service integration in `thingsboard_service.dart`.

## Key Dependencies
- ThingsBoard RPC mechanisms (One-way and Two-way models).
- ESP32 hardware connection to ThingsBoard.
