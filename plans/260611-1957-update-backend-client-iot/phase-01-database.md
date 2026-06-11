# Phase 1: Database Migration & Schema Design

## Context Links
- [V1__init_schema.sql](file:///h:/SideProjects/iot-ptit-2026/server/src/main/resources/db/migration/V1__init_schema.sql)
- [Scout Report](file:///h:/SideProjects/iot-ptit-2026/plans/reports/scout-260611-1957-update-backend-client-iot.md)

## Overview
- **Priority**: HIGH
- **Current Status**: PENDING
- **Description**: Add `mist_on` and `water_low` columns to telemetry data table. Design and create two new tables to persist threshold changes history and warnings/alerts history.

## Key Insights
- Since PostgreSQL is used with validation (`ddl-auto=validate`), we MUST write correct Flyway migrations.
- We should model these new columns and tables using standard JPA Hibernate entities in Spring Boot.

## Requirements
- Flyway SQL migration script to alter existing table and create two new tables.
- Entities in Java for `ThresholdHistory` and `AlertLog`.
- JPA Repository interfaces for CRUD operations on these new entities.

## Architecture
- Telemetry database:
  - Add `mist_on` (boolean), `water_low` (boolean) to `telemetry_data`.
  - Add `threshold_history` table for persisting each threshold update.
  - Add `alert_log` table for logging warnings/alerts (DUST, GAS, WATER_LOW, TEMP, HUMIDITY).

## Related Code Files
- [NEW] [V2__add_mist_and_water.sql](file:///h:/SideProjects/iot-ptit-2026/server/src/main/resources/db/migration/V2__add_mist_and_water.sql)
- [MODIFY] [TelemetryData.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/model/TelemetryData.java)
- [NEW] [ThresholdHistory.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/model/ThresholdHistory.java)
- [NEW] [AlertLog.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/model/AlertLog.java)
- [NEW] [ThresholdHistoryRepository.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/repository/ThresholdHistoryRepository.java)
- [NEW] [AlertLogRepository.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/repository/AlertLogRepository.java)

## Implementation Steps
1. Create `V2__add_mist_and_water.sql` in `db/migration`.
2. Add fields to `TelemetryData.java`.
3. Create `ThresholdHistory.java` and `AlertLog.java` JPA entities.
4. Create the repositories.

## Todo List
- [ ] Create Flyway SQL migration
- [ ] Update `TelemetryData` entity
- [ ] Create `ThresholdHistory` entity and repository
- [ ] Create `AlertLog` entity and repository

## Success Criteria
- SQL script executes correctly during build.
- Database compiles without JPA model mismatch errors.
- Schema is validated successfully.

## Risk Assessment
- *Risk*: Database sync issue on Neon DB.
- *Mitigation*: Ensure SQL matches standard PostgreSQL syntax.

## Security Considerations
- Data schema fields map correctly to Java types.
