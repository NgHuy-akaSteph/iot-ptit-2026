# Phase 3: Flutter Settings UI

## Context Links
- **Researcher Report**: [researcher-260603-1741-configurable-thresholds.md](file:///h:/SideProjects/iot-ptit-2026/plans/reports/researcher-260603-1741-configurable-thresholds.md)
- **Settings Panel**: [settings_panel.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/widgets/settings_panel.dart)
- **ThingsBoard Service**: [thingsboard_service.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/service/thingsboard_service.dart)

## Overview
- **Priority**: HIGH
- **Current Status**: TODO
- **Description**: Add threshold settings inputs to the Settings tab, manage text-editing controllers, enforce validation ranges (e.g. `Med < High`), and execute REST API calls using Dio.

## Key Insights
- **Form Validation**: Fields must only accept valid floating-point numbers. Setting threshold values to negative or extremely high values must be blocked to prevent hardware issues.
- **Aesthetic Consistency**: The UI must follow the established style guidelines: card layout, custom border highlights, and loading indicators for a premium user experience.

## Requirements
- Fields: Dust High, Dust Med, Gas High, Gas Med.
- Check that Med is less than High.
- Fetch current settings from backend on screen initialization.
- Show clear feedback upon successful or failed save operations.

## Related Code Files
- [MODIFY] [thingsboard_service.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/service/thingsboard_service.dart)
- [MODIFY] [settings_panel.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/widgets/settings_panel.dart)

## Implementation Steps
1. In `thingsboard_service.dart`, add `getThresholds()` and `updateThresholds(...)` mapping to the new endpoints in the Spring Boot BFF.
2. In `settings_panel.dart`, create text editing controllers and form state variables.
3. In `initState()`, fetch the thresholds from the backend service. If successful, pre-fill the text fields. Show sensible defaults on failure or if empty.
4. Add a "Ngưỡng cảnh báo" (Alert Thresholds) section structured as a card. Integrate the input fields with clean labels and helper text.
5. Implement form validation checking that input values are positive numbers and that `dustMed < dustHigh` and `gasMed < gasHigh`.
6. Add a submit button with a progress spinner that performs `updateThresholds(...)` and provides success/error notifications.

## Todo List
- [ ] Add `getThresholds` and `updateThresholds` functions in `thingsboard_service.dart`.
- [ ] Initialize form controllers and fetch values in `settings_panel.dart`.
- [ ] Add the Form UI with 4 inputs and validation checks.
- [ ] Integrate submit handler and call service API.
- [ ] Verify Flutter application compiles successfully.

## Success Criteria
- The Flutter client runs and accesses the settings page.
- Opening settings triggers a GET call to load threshold values.
- Saving updates settings correctly on the server/device.
- SnackBar displays accurate success/error results.
