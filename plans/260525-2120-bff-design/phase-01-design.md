# Phase 1: Core Design & Architectural Layout

## Context Links
- Brainstormer Report: [brainstormer-260525-2120-bff-design.md](file:///h:/SideProjects/iot-ptit-2026/plans/reports/brainstormer-260525-2120-bff-design.md)
- Main Plan: [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/plan.md)

## Overview
- **Priority**: HIGH
- **Status**: COMPLETED
- **Description**: Technical layout, system workflow, API specifications, database design for the BFF backend.

## Key Insights
- Mediate authentication statelessly by generating custom JWTs that encapsulate the ThingsBoard JWT.
- Mediate telemetry collection using ThingsBoard's Rule Chain REST API Call node for real-time pushing.
- Log RPC Commands synchronously to PostgreSQL before proxying to ThingsBoard.

## Requirements
- Support stateless authentication mapped to Thingsboard.
- Define DB schema for telemetry data and command logs.
- Define HTTP API endpoints for auth, telemetry retrieval, and RPC commands.

## Architecture
- Custom Spring Security filter to extract and decrypt Thingsboard JWT from BFF JWT.
- Non-blocking `WebClient` to communicate asynchronously with ThingsBoard cloud APIs.

## Related Code Files
- [NEW] [SecurityConfig.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/config/SecurityConfig.java)
- [NEW] [ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java)

## Success Criteria
- Validated REST API endpoint layout.
- Approved stateless auth sequence.
