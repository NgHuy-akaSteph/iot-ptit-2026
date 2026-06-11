# Phase 2: Mobile App Optimistic UI

## Context Links
- **Source**: [dashboard_screen.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/screen/dashboard_screen.dart)

## Overview
- **Priority**: HIGH
- **Current Status**: TODO
- **Description**: Add optimistic UI updates on the Flutter client so the controls (Auto mode toggle and fan level buttons) react instantly, providing a seamless user experience.

## Key Insights
- The HTTP requests to BFF on Render have round-trip latencies of 1-2s. Waiting for completion makes controls feel laggy.
- Optimistic updates apply the state change in the UI immediately, and then revert the change if the backend request eventually fails.

## Requirements
- Instantly toggle the Auto/Manual mode switch.
- Instantly select fan speed levels (Thấp, Trung, Cao).
- If the backend call fails, revert the state to the previous value and display the error snackbar.

## Related Code Files
- [dashboard_screen.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/screen/dashboard_screen.dart)

## Implementation Steps
1. Update `_handleAutoModeChange` to save the old state, perform `setState` immediately, and run the request in the background. If the request fails, restore the old state and trigger `setState` + snackbar.
2. Update `_handleFanLevelChange` to similarly apply optimistic updates for the fan speed buttons.

## Todo List
- [ ] Implement optimistic update for `_handleAutoModeChange`
- [ ] Implement optimistic update for `_handleFanLevelChange`

## Success Criteria
- Instant visual feedback upon user tap.
- Correct state rollback and error message in case of network/server failure.
