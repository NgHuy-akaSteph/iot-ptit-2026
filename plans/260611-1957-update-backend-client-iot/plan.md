---
title: "Adapt Backend and Frontend to Device Upgrades"
description: "Modify Spring Boot database tables, save ThingsBoard telemetry calls, track threshold adjustments, log warnings/alerts, and update Flutter application with water level and misting controls."
status: "planning"
priority: "HIGH"
effort: "MEDIUM"
branch: "feature/device-telemetry-upgrade"
tags: ["spring-boot", "flutter", "postgresql", "thingsboard"]
created: "2026-06-11"
---

# Plan Overview

This plan covers updates required across the database, Spring Boot BFF, and Flutter client to match ESP32 changes.

## Phase Overview

- [Phase 1: Database Migration & Schema Design](file:///h:/SideProjects/iot-ptit-2026/plans/260611-1957-update-backend-client-iot/phase-01-database.md) (Status: PENDING)
- [Phase 2: Backend Implementation](file:///h:/SideProjects/iot-ptit-2026/plans/260611-1957-update-backend-client-iot/phase-02-backend.md) (Status: PENDING)
- [Phase 3: Frontend Implementation](file:///h:/SideProjects/iot-ptit-2026/plans/260611-1957-update-backend-client-iot/phase-03-frontend.md) (Status: PENDING)

## Key Dependencies

- ThingsBoard timeseries response payload format matching.
- Database access (Flyway migrations execution on application start).
- ESP32 MQTT topic payload verification.
