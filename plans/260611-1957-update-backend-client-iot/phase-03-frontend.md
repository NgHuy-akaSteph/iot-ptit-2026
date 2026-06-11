# Phase 3: Frontend Implementation

## Context Links
- [enviroment_data.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/model/enviroment_data.dart)
- [dashboard_screen.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/screen/dashboard_screen.dart)
- [control_panel.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/widgets/control_panel.dart)

## Overview
- **Priority**: HIGH
- **Current Status**: PENDING
- **Description**: Add `mistOn` and `waterLow` fields to the Flutter environment model. Update the dashboard grid to show Water Level and Misting status. Add a switch to toggle misting state in manual mode.

## Key Insights
- The Misting state toggle can only be used when Auto Mode is turned off.
- The Water Level card should show a clear warning (e.g. flash red) if the tank is empty.

## Requirements
- Update `EnvironmentData` model parsing from JSON.
- Add "Mực nước" (Water Level) card and "Trạng thái Phun sương" (Misting state) card to Dashboard Overview.
- Add Mist Toggle Switch to the control panel, disabled during Auto Mode.
- Optional/Bonus: Add a logs tab or sub-panel to display alerts history and threshold history retrieved from the BFF API.

## Related Code Files
- [MODIFY] [enviroment_data.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/model/enviroment_data.dart)
- [MODIFY] [dashboard_screen.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/screen/dashboard_screen.dart)
- [MODIFY] [control_panel.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/widgets/control_panel.dart)
- [MODIFY] [thingsboard_service.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/service/thingsboard_service.dart)

## Implementation Steps
1. Update `EnvironmentData` in `enviroment_data.dart` to support `mistOn` and `waterLow`.
2. Update `ThingsBoardService` in `thingsboard_service.dart` to support sending the `setMist` RPC command.
3. Update `ControlPanel` widget in `control_panel.dart` to accept mist control callback and show the switch.
4. Integrate the new cards and controls inside `dashboard_screen.dart`.
5. Optional: Add a premium UI modal or section to show "Lịch sử cảnh báo" (Alert History) and "Lịch sử ngưỡng" (Threshold History).

## Todo List
- [ ] Update `EnvironmentData` model
- [ ] Add `setMist` RPC command to `ThingsBoardService`
- [ ] Update `ControlPanel` widget to include Mist toggle
- [ ] Update `dashboard_screen.dart` with new cards and mist toggle callback
- [ ] Add alert & threshold history viewer in UI
- [ ] Build/Verify Flutter client layout

## Success Criteria
- Flutter app compiles and runs.
- Misting status and Water Level are displayed correctly.
- Manual mist switch sends RPC to device when Auto Mode is disabled.
- The UI displays alert logs beautifully.
