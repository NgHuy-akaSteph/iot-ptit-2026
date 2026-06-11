---
title: Mist Module & Water Level Sensor
description: Add water level switch sensor (GPIO 2) and misting relay (GPIO 33) with NVS-configurable thresholds and manual RPC control.
status: COMPLETE
priority: HIGH
effort: EASY
branch: feature/mist-and-water-sensor
tags: [device, sensor, freeRTOS, mqtt, preferences]
created: 2026-06-11
---

# Plan: Mist Module & Water Level Sensor

Add GPIO definitions, tasks, control loop updates, MQTT integration, and LCD updates to support misting and water-level sensing.

## Phases

- **[Phase 1: ESP32 Firmware Implementation](file:///h:/SideProjects/iot-ptit-2026/plans/260611-1717-add-mist-and-water-level-sensor/phase-01-device.md)**: `DONE`
  - Define pins, struct members, and variables.
  - Implement `waterSwitchTask` and safety cutoff logic.
  - Integrate misting control in `controlTask` with NVS preferences.
  - Update `onMqttMessage` for configurable thresholds and `setMist` RPC command.

## Key Dependencies
- PlatformIO build toolchain
- ESP32 hardware configurations
