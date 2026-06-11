# Phase 2: Database and Persistence Layer Setup

## Context Links
- Main Plan: [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/plan.md)
- Schema Design: [brainstormer-260525-2120-bff-design.md](file:///h:/SideProjects/iot-ptit-2026/plans/reports/brainstormer-260525-2120-bff-design.md)

## Overview
- **Priority**: HIGH
- **Status**: PENDING
- **Description**: Configure PostgreSQL connection, Flyway migrations, JPA entities, and Spring Data Repositories for telemetry and command logs.

## Key Insights
- Keep DB files separate and clean using Flyway for schema version control.
- Telemetry values are stored as double precision to accommodate sensor data (temperature, humidity, dust, gas).

## Requirements
- PostgreSQL connectivity via standard Spring properties.
- Migration script creating `telemetry_data` and `command_log` tables.
- JPA entities map precisely to the columns.
- Spring Data repositories for operations.

## Related Code Files
- [MODIFY] [application.properties](file:///h:/SideProjects/iot-ptit-2026/server/src/main/resources/application.properties)
- [NEW] [V1__init_schema.sql](file:///h:/SideProjects/iot-ptit-2026/server/src/main/resources/db/migration/V1__init_schema.sql)
- [NEW] [TelemetryData.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/model/TelemetryData.java)
- [NEW] [CommandLog.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/model/CommandLog.java)
- [NEW] [TelemetryRepository.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/repository/TelemetryRepository.java)
- [NEW] [CommandLogRepository.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/repository/CommandLogRepository.java)

## Implementation Steps
1. Add PostgreSQL & database configuration inside `application.properties`.
2. Create Flyway migration script `V1__init_schema.sql`.
3. Implement Lombok-annotated JPA entities `TelemetryData` and `CommandLog`.
4. Create interface repositories extending `JpaRepository`.

## Todo List
- [ ] Add properties to `application.properties`
- [ ] Write initialization SQL script for Flyway
- [ ] Implement `TelemetryData` JPA entity
- [ ] Implement `CommandLog` JPA entity
- [ ] Implement repositories

## Success Criteria
- Spring Boot app successfully builds and boots.
- Flyway automatically creates the tables in the PostgreSQL database.
