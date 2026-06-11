---
title: Fix RPC Delay and Error
description: Fix empty-body reactive bug causing HTTP 400 Bad Request in BFF server and implement optimistic updates on Flutter mobile app.
status: IN_PROGRESS
priority: HIGH
effort: SMALL
branch: fix/rpc-delay-error
tags: [backend, mobile, rpc, thingsboard]
created: 2026-06-02
---

# Plan: Fix RPC Delay and Error

This plan addresses the issue where controlling the device (auto/manual mode and fan level) shows an error snackbar and is delayed, but eventually completes the action.

## Phases

- **[Phase 1: BFF Backend Fix](file:///h:/SideProjects/iot-ptit-2026/plans/260602-0924-fix-rpc-delay-error/phase-01-fix-rpc-bug.md)**: `IN_PROGRESS`
  - Fix WebClient empty body mapping in `ThingsboardClient.java`.
  - Validate database command log persistence.

- **[Phase 2: Mobile App Optimistic UI](file:///h:/SideProjects/iot-ptit-2026/plans/260602-0924-fix-rpc-delay-error/phase-02-optimistic-ui.md)**: `TODO`
  - Implement optimistic UI updates in `dashboard_screen.dart`.
  - Improve UI responsiveness for manual control.

## Key Dependencies
- ThingsBoard API `/api/plugins/rpc/oneway/{deviceId}` behavior (confirmed to return empty body).
