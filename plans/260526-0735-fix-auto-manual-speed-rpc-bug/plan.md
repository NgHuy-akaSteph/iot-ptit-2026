---
title: Fix Auto-Manual Mode & Speed RPC Bug
description: Fixes transaction errors in Spring BFF RPC and integer parsing bugs in ESP32 firmware (firmware skipped)
status: in-progress
priority: HIGH
effort: MEDIUM
branch: main
tags: [backend, spring-boot, flutter]
created: 2026-05-26
---

# Plan: Fix Auto-Manual & Speed RPC Bug

## Phases

- **Phase 01**: Implement backend Spring BFF fixes using `TransactionTemplate` & `Schedulers.boundedElastic()`.
  - *Link*: [phase-01-backend.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0735-fix-auto-manual-speed-rpc-bug/phase-01-backend.md)
  - *Status*: Complete

- **Phase 02**: Implement ESP32 firmware parsing fix for `setFan` RPC params.
  - *Link*: [phase-02-device.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0735-fix-auto-manual-speed-rpc-bug/phase-02-device.md)
  - *Status*: SKIPPED

- **Phase 03**: Verify changes (compile check and full end-to-end trace validation).
  - *Link*: [phase-03-verification.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0735-fix-auto-manual-speed-rpc-bug/phase-03-verification.md)
  - *Status*: Complete

## Key Dependencies
- Neon PostgreSQL connection must be active.
- Flutter client requires rebuild if code standards require changes, though client remains unchanged.
