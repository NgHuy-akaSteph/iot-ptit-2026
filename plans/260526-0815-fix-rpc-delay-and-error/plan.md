---
title: Fix RPC Delay and Error handling
description: Swaps two-way RPC to one-way for instant responses and implements correct HTTP error status propagation to Flutter client
status: complete
priority: HIGH
effort: LOW
branch: main
tags: [backend, spring-boot, flutter]
created: 2026-05-26
---

# Plan: Fix RPC Delay and Error handling

## Phases

- **Phase 01**: Implement backend Spring BFF fixes.
  - *Link*: [phase-01-backend.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0815-fix-rpc-delay-and-error/phase-01-backend.md)
  - *Status*: Complete

- **Phase 02**: Verify changes (compile check, end-to-end telemetry and RPC verification).
  - *Link*: [phase-02-verification.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0815-fix-rpc-delay-and-error/phase-02-verification.md)
  - *Status*: Complete

## Key Dependencies
- ThingsBoard API must be accessible.
- DB connection must be configured.
