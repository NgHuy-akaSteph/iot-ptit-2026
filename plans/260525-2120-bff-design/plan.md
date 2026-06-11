---
title: Spring Boot BFF Implementation for ThingsBoard IoT Project
description: Introduce a Spring Boot Backend For Frontend (BFF) to mediate auth, proxy telemetry, log RPC, and store historical data in PostgreSQL.
status: IN_PROGRESS
priority: HIGH
effort: 3-5 days
branch: feature/bff-integration
tags: [springboot, flutter, thingsboard, backend, iot]
created: 2026-05-25
---

# Spring Boot BFF Implementation Plan

## 1. Overview
Introduce a Spring Boot BFF between Flutter and ThingsBoard to:
1. Handle authentication and session management.
2. Proxy and store telemetry data in PostgreSQL (from ThingsBoard webhook or proxy request).
3. Log and proxy 2-way RPC commands to ESP32 devices via ThingsBoard.

## 2. Phases & Progress

- [x] **Phase 1: Research and Core Design**
  - Status: Completed (Brainstorming report created)
  - Detail: [phase-01-design.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/phase-01-design.md)
  
- [x] **Phase 2: Database and Persistence Layer Setup**
  - Status: Completed
  - Detail: [phase-02-persistence.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/phase-02-persistence.md)
  
- [x] **Phase 3: BFF Authentication and ThingsBoard Integration**
  - Status: Completed
  - Detail: [phase-03-integration.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/phase-03-integration.md)

- [x] **Phase 4: Telemetry Webhook & RPC Proxy Endpoints**
  - Status: Completed
  - Detail: [phase-04-endpoints.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/phase-04-endpoints.md)

- [x] **Phase 5: Flutter Client Migration & Verification**
  - Status: Completed
  - Detail: [phase-05-migration.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/phase-05-migration.md)

## 3. Key Dependencies
- PostgreSQL (database for local persistence)
- ThingsBoard Account / API Access
- Webflux WebClient (for downstream REST calls)
- Spring Boot Starter Security (for JWT resource server and token handling)
