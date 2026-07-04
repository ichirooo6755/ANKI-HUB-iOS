# Study Session Recording Feature

## Overview
A comprehensive study session recording system that allows users to track their study time with detailed segment markers (pins) for better learning analytics.

## Features Implemented

### 1. Study Session Manager (`StudySessionManager.swift`)
- **Singleton manager** for handling active and completed study sessions
- **Real-time tracking** with automatic timer updates
- **Pin markers** to segment study sessions by subject and activity
- **Persistence** using App Group UserDefaults for widget integration
- **Learning stats integration** to update daily history with segment details

### 2. UI Components

#### Study Session Bento Card (`StudySessionBentoCard.swift`)
- **Horizontal bento-style card** displayed at the top of the Study tab
- **Inactive state**: Shows "勉強スタート" button to begin a session
- **Active state**: 
  - Displays elapsed time with pulsing indicator
  - Shows current segment time
  - Pin button to mark segments
  - Stop button to end session
- **Pin Recording Sheet**: Modal form to record:
  - Subject (English, Kobun, Kanbun, Seikei)
  - Activity type (単語学習, 文法学習, 問題演習, etc.)
  - Optional notes

### 3. Widget Integration
- **New URL schemes** for widget controls:
  - `sugwranki://session/start` - Start a study session
  - `sugwranki://session/stop` - Stop the current session
  - `sugwranki://session/pin` - Open pin recording sheet
- **Control Widgets** (iOS 18+):
  - `SessionStartControlWidget` - Quick start button
  - `SessionStopControlWidget` - Quick stop button
  - `SessionPinControlWidget` - Quick pin button
- **Deep link handling** in `MainTabView` for all session actions

### 4. Calendar Integration
- **Session segments display** in day detail view
- Shows all completed sessions for a specific day
- **Segment breakdown** with:
  - Time range (HH:mm - HH:mm)
  - Total session duration
  - Individual segment details (subject, activity, duration, notes)
- **Visual hierarchy** with cards and nested segment lists

## Data Models

### ActiveStudySession
```swift
struct ActiveStudySession: Codable {
    var id: UUID
    var startTime: Date
    var pins: [PinMarker]
    var currentSegmentStart: Date
}
```

### PinMarker
```swift
struct PinMarker: Codable, Identifiable {
    var id: UUID
    var timestamp: Date
    var subject: String
    var activity: String
    var notes: String
    var durationSeconds: Int
}
```

### CompletedSession
```swift
struct CompletedSession: Codable, Identifiable {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var totalMinutes: Int
    var segments: [PinMarker]
}
```

## User Flow

1. **Start Session**: User taps "勉強スタート" button on Study tab or uses widget
2. **Study & Pin**: During study, user can tap "ピン" button to mark segments
3. **Record Details**: For each pin, user records:
   - What subject they studied
   - What activity they did
   - Optional notes about the segment
4. **Stop Session**: User taps stop button when done
5. **View History**: User can see detailed breakdown in Calendar view

## Integration Points

### LearningStats Integration
- Completed sessions automatically update `LearningStats.dailyHistory`
- Segment details are aggregated by subject
- Total minutes are added to the day's entry
- Widget timeline is refreshed after each update

### App Group Sharing
- Uses `group.com.ankihub.ios` for data sharing
- Active session persists across app launches
- Widget can read session state for display

## Files Modified/Created

### Created:
- `Sources/ANKI-HUB-iOS/Managers/StudySessionManager.swift`
- `Sources/ANKI-HUB-iOS/UI/Components/StudySessionBentoCard.swift`
- `docs/STUDY_SESSION_FEATURE.md`

### Modified:
- `Sources/ANKI-HUB-iOS/UI/StudyView.swift` - Added bento card at top
- `Sources/ANKI-HUB-iOS/UI/MainTabView.swift` - Added session URL handling
- `Sources/ANKI-HUB-iOS-Widget/ANKI_HUB_iOS_Widget.swift` - Added control widgets
- `Sources/ANKI-HUB-iOS/UI/AppCalendarView.swift` - Added session segments display

## Future Enhancements

Potential improvements for future iterations:
- Export session data to CSV/JSON
- Session templates for common study patterns
- Automatic subject detection based on app usage
- Session goals and reminders
- Weekly/monthly session analytics
- Integration with Pomodoro timer
- Voice input for pin recording
- Session sharing with study groups
