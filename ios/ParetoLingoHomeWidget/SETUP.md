# iOS Widget Target Setup

This folder contains WidgetKit source files, but Xcode target wiring is still required.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. File -> New -> Target -> Widget Extension.
3. Name it `ParetoLingoHomeWidget`.
4. When prompted, activate the new scheme.
5. Replace generated widget files with:
   - `ParetoLingoHomeWidget.swift`
   - `ParetoLingoHomeWidgetBundle.swift`
   - `Info.plist`
6. In Signing & Capabilities:
   - Add App Groups to Runner and the widget target.
   - Add `group.com.example.pareto_lingo` to both.
7. Build and run on iOS, then add the widget from the home screen.

The Flutter side already updates these keys through `home_widget`:
- `pl_streak`
- `pl_reminder_enabled`
- `pl_reminder_hour`
- `pl_reminder_minute`
- `pl_language_flag`
