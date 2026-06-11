# Scout Report: Codebase Audit & Update Scope

**Date**: 260611
**Time**: 19:57
**Task**: Update backend and frontend to adapt to device code changes

---

## 1. Codebase Discovery

### Device (ESP32) Status
- Telemetry publishes (`temperature`, `humidity`, `dust_ug`, `gas_ppm`, `auto_mode`, `fan_level`, `mist_on`, `water_low`).
- New controls added for manual Misting (`setMist`) and automatic Misting triggered by temperature/humidity.

### Backend (Spring Boot BFF) Structure
- **Entity**: `TelemetryData.java` does not contain `mist_on` and `water_low` fields.
- **Repository**: `TelemetryRepository.java` handles queries for history and latest records.
- **Service**: `TelemetryService.java` is used to save telemetry.
- **Controller**: `TelemetryController.java` exposes `/latest` which checks DB, and falls back to Thingsboard only if empty.
- **RPC Service**: `RpcService.java` sends commands but does not save thresholds to database history.
- **Database**: Schema `V1__init_schema.sql` needs migration for additional fields and tables.

### Frontend (Flutter) Structure
- **Model**: `EnvironmentData.dart` needs updating to support `mistOn` and `waterLow`.
- **Screen**: `dashboard_screen.dart` needs display grids/cards for water level and misting status, plus control panel switch for manual misting when autoMode is off.
- **Widgets**: `control_panel.dart` needs layout adjustment to add Mist toggle.

---

## 2. Plan of Actions

1. **Database Migration**: Create `V2__add_mist_and_water.sql` to add columns and new history tables (`threshold_history`, `alert_log`).
2. **Backend Code Updates**:
   - Update `TelemetryData` entity to include `mistOn` and `waterLow`.
   - Update `TelemetryService` to evaluate warning/alerts and log them in `alert_log`.
   - Update `TelemetryController` to fetch from Thingsboard and save/update the local DB on every request.
   - Update `RpcService` to log successful `setThresholds` commands to `threshold_history`.
   - Expose endpoints for `threshold_history` and `alert_log`.
3. **Frontend Flutter Updates**:
   - Update model `EnvironmentData` to parse `mist_on` and `water_low`.
   - Update `dashboard_screen.dart` with cards for water status and mist status, and tabs for alert/threshold logs.
   - Update `control_panel.dart` to add the manual mist switch.
