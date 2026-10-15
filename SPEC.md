# Traverse - Complete Build Specification

## What is Traverse?

Traverse is an iOS app that passively tracks your entire day — where you go, how you get there, and how long you stay. It is a faithful recreation of the original **Moves** app (by ProtoGeo, 2013-2018) with one addition: explicit **vehicle/driving** tracking alongside walking, running, and cycling.

The app runs silently in the background. There are no buttons to start or stop tracking. You open the app and see your day laid out as a vertical storyline — a narrative of your movement through the world.

---

## Project Setup

- **IDE**: Xcode (latest stable)
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Minimum iOS Target**: iOS 17.0
- **Bundle Identifier**: already set in the existing Xcode project at `/Traverse/Traverse.xcodeproj`
- **Existing files**: `TraverseApp.swift`, `ContentView.swift`, `Item.swift` (boilerplate — replace as needed)
- **Data persistence**: SwiftData (no Core Data, no Realm)
- **No external dependencies or packages** — use only Apple frameworks

### Required Frameworks

| Framework | Purpose |
|-----------|---------|
| CoreLocation | GPS tracking, visit monitoring, geocoding |
| CoreMotion | Activity classification (walk/run/cycle/vehicle/stationary), pedometer |
| MapKit | Map rendering, reverse geocoding, POI lookup |
| SwiftData | Local persistence of timeline, places, segments |
| SwiftUI | All UI |

### Required Capabilities (in Xcode Signing & Capabilities)

- **Background Modes**: Location updates
- **Location**: Always and When In Use

### Required Info.plist Keys

| Key | Value (user-facing string) |
|-----|---------------------------|
| `NSLocationAlwaysAndWhenInUseUsageDescription` | "Traverse tracks your location throughout the day to build your personal movement timeline." |
| `NSLocationWhenInUseUsageDescription` | "Traverse needs your location to show where you are on the map." |
| `NSMotionUsageDescription` | "Traverse uses motion data to detect whether you're walking, running, cycling, or driving." |

---

## Architecture Overview

```
Traverse/
├── TraverseApp.swift              # App entry point, setup permissions on launch
├── Models/
│   ├── TimelineSegment.swift      # A single activity segment (walk, run, drive, etc.)
│   ├── PlaceVisit.swift           # A place the user stayed at (with arrival/departure)
│   └── DaySummary.swift           # Aggregated stats for a single day
├── Services/
│   ├── LocationService.swift      # Core Location wrapper — GPS + visits
│   ├── MotionService.swift        # Core Motion wrapper — activity detection + pedometer
│   ├── TimelineEngine.swift       # Merges location + motion into timeline segments
│   └── PlaceResolver.swift        # Reverse geocoding + POI identification
├── Views/
│   ├── StorylineView.swift        # Main screen — activity bubbles + vertical timeline
│   ├── ActivityBubbleView.swift   # A single colored activity circle
│   ├── ActivityBubblesRow.swift   # Horizontal row of activity bubbles
│   ├── TimelineSegmentRow.swift   # A single row in the storyline (activity or place)
│   ├── PlaceDetailView.swift      # Tapped place — shows time spent, address
│   ├── ActivityDetailView.swift   # Tapped activity — shows duration, distance, steps, route
│   ├── DayMapView.swift           # Full-day map with color-coded routes
│   ├── DaySelectorView.swift      # Swipe or tap to change which day you're viewing
│   └── SettingsView.swift         # Minimal settings screen
├── Utilities/
│   ├── ColorTheme.swift           # Activity colors defined in one place
│   └── Extensions.swift           # Date formatting, distance formatting, etc.
└── Assets.xcassets/               # App icon, accent color
```

---

## Data Models (SwiftData)

### TimelineSegment

Represents a contiguous period of a single activity type.

```
@Model TimelineSegment {
    id: UUID
    activityType: ActivityType     // enum: walking, running, cycling, vehicle, stationary
    startTime: Date
    endTime: Date?                 // nil if ongoing
    steps: Int?                    // only for walking/running
    distanceMeters: Double?        // from pedometer or GPS
    routeCoordinates: [CoordinatePoint]  // GPS breadcrumbs for map drawing
    confidence: ActivityConfidence // enum: low, medium, high
}
```

### PlaceVisit

Represents a stop at a location.

```
@Model PlaceVisit {
    id: UUID
    latitude: Double
    longitude: Double
    arrivalTime: Date
    departureTime: Date?           // nil if still there
    name: String?                  // resolved place name ("Starbucks", "Home")
    address: String?               // street address
    category: PlaceCategory?       // enum: home, work, food, shop, gym, entertainment, other
    isUserLabeled: Bool            // true if user manually named this place
}
```

### CoordinatePoint

Lightweight coordinate storage (since CLLocationCoordinate2D isn't Codable).

```
@Model CoordinatePoint {
    latitude: Double
    longitude: Double
    timestamp: Date
}
```

### Enums

```swift
enum ActivityType: String, Codable {
    case walking
    case running
    case cycling
    case vehicle
    case stationary
}

enum ActivityConfidence: String, Codable {
    case low, medium, high
}

enum PlaceCategory: String, Codable {
    case home, work, food, shop, gym, entertainment, transit, other
}
```

---

## Services — How Tracking Works

### LocationService

Wraps `CLLocationManager`. Responsibilities:

1. **Request "Always" location authorization** on first launch.
2. **Start visit monitoring** (`startMonitoringVisits()`) — this is the primary mechanism for detecting when the user arrives at or leaves a place. Each `CLVisit` has `coordinate`, `arrivalDate`, `departureDate`. Create a `PlaceVisit` from each visit.
3. **Start significant location change monitoring** (`startMonitoringSignificantLocationChanges()`) — wakes the app from background when the user moves ~500m. Use this as a trigger to start more precise tracking.
4. **Standard location updates** — when the user is actively moving (detected via MotionService), switch to standard GPS updates at `kCLLocationAccuracyBest` with a `distanceFilter` of 10 meters. Collect these as route breadcrumbs for map drawing. When the user becomes stationary, stop standard updates to save battery.
5. **Set `allowsBackgroundLocationUpdates = true`** and `pausesLocationUpdatesAutomatically = true`.
6. **Set `activityType`** on the location manager to `.fitness` (for walking/running) or `.automotiveNavigation` (when vehicle is detected) — this helps iOS optimize GPS behavior.

**Battery optimization strategy**:
- When stationary → visit monitoring only (near zero battery cost)
- When moving on foot → GPS at 10m distance filter
- When in vehicle → GPS at 25m distance filter (less precision needed)
- When battery < 20% → fall back to significant location changes only

### MotionService

Wraps `CMMotionActivityManager` and `CMPedometer`. Responsibilities:

1. **Start activity updates** (`startActivityUpdates(to:)`) — receive real-time callbacks when activity type changes. Map `CMMotionActivity` flags to our `ActivityType` enum:
   - `.walking == true` → `.walking`
   - `.running == true` → `.running`
   - `.cycling == true` → `.cycling`
   - `.automotive == true` → `.vehicle`
   - `.stationary == true` → `.stationary`
   - `.unknown == true` → ignore or treat as previous state
   - If multiple flags are true (e.g., stationary + automotive at a red light), prefer the transport mode over stationary.
2. **Query historical activities** (`queryActivityStarting(from:to:)`) — on app launch, backfill any gaps from when the app was suspended. Core Motion stores up to 7 days of data.
3. **Start pedometer updates** (`startUpdates(from:)`) — get live step count and distance for walking/running segments.
4. **Query pedometer data** for specific time ranges to attach step counts to completed segments.

### TimelineEngine

This is the brain. It merges data from LocationService and MotionService into a coherent timeline. Responsibilities:

1. **Segment creation**: When MotionService reports an activity change (e.g., stationary → walking), create a new `TimelineSegment` with the new activity type and start time. End the previous segment.
2. **Segment merging**: If the user briefly flickers between states (e.g., 10 seconds of "unknown" between two walking segments), merge them into one walking segment. Use a minimum segment duration of **2 minutes** — anything shorter gets absorbed into the surrounding segment.
3. **Place integration**: When LocationService reports a `CLVisit`, find the corresponding stationary segment in the timeline and attach a `PlaceVisit` to it. If no stationary segment exists for that time window, create one.
4. **Route attachment**: Attach GPS breadcrumbs from LocationService to the active movement segment.
5. **Gap recovery**: On app launch, query Core Motion history and Core Location's last known location to reconstruct any missed segments while the app was suspended.
6. **Daily rollover**: At midnight (local time), finalize the day's timeline. All open segments get an end time of 23:59:59 and new ones start at 00:00:00.

### PlaceResolver

Handles turning coordinates into human-readable names. Responsibilities:

1. **Reverse geocode** every `PlaceVisit` coordinate using `CLGeocoder.reverseGeocodeLocation`. Extract the best available name from `CLPlacemark` — prefer `name` (POI name) > `areasOfInterest` > street address.
2. **POI search**: If reverse geocoding doesn't return a venue name, do an `MKLocalSearch` around the coordinate with a small radius (~50m) to find nearby businesses/landmarks.
3. **Home/Work inference**: After 3+ days of data:
   - The location where the user spends most nights (10pm-6am) → suggest labeling as "Home"
   - The location where the user spends most weekday daytime hours → suggest labeling as "Work"
   - Show a subtle prompt: "Is this your home?" / "Is this your workplace?" — let the user confirm or dismiss.
4. **User labeling**: Let users tap any place to rename it. Persist the label so future visits to the same coordinate cluster use the same name.
5. **Coordinate clustering**: Two visits within ~100 meters of each other should be treated as the same place. Use the centroid of all visits as the canonical coordinate.

---

## UI Specification

### Design Philosophy

- **White/light background** everywhere
- **Minimal chrome** — almost no visible buttons or navigation bars
- **The data IS the interface** — activity bubbles and the timeline are the entire UI
- **Progressive disclosure** — summary at top, details on tap
- **Passive feel** — the app should feel like it's quietly observing, not demanding interaction

### Color Palette

Define these in `ColorTheme.swift`:

| Activity | Color | Hex |
|----------|-------|-----|
| Walking | Green | `#5DB37E` |
| Running | Pink/Red | `#E85D75` |
| Cycling | Blue | `#4A90D9` |
| Vehicle | Orange | `#F5A623` |
| Stationary/Place | Gray | `#9B9B9B` |
| Background | White | `#FFFFFF` |
| Primary text | Dark gray | `#4A4A4A` |
| Secondary text | Medium gray | `#9B9B9B` |

### Typography

- Use the system font (San Francisco) throughout
- Large numbers (step count, distance): `.system(size: 28, weight: .light)`
- Activity labels: `.system(size: 13, weight: .medium)`
- Timeline place names: `.system(size: 16, weight: .semibold)`
- Timeline details (time, duration): `.system(size: 13, weight: .regular)`, secondary text color
- Section headers (date): `.system(size: 15, weight: .medium)`

---

### Screen 1: Storyline View (Main Screen)

This is the only screen the user sees 95% of the time. It is a single vertically scrollable view.

#### Layout (top to bottom):

**1. Status bar area** — standard iOS status bar, no custom styling.

**2. Date header** — centered at the top.
- Shows the current date: "Today" or "Mon, Feb 3"
- Swipe left/right on the entire screen to navigate between days
- Subtle left/right chevrons appear at the edges during swipe

**3. Activity Bubbles Row** — horizontally centered, directly below the date.
- A row of **circles**, one per activity type that occurred today
- Each circle is filled with the activity's color
- **Circle size is proportional** to the duration of that activity relative to others. The largest activity gets the biggest circle (~80pt diameter), and others scale down proportionally. Minimum circle size is ~36pt.
- Inside each circle: the primary metric in white text
  - Walking: step count (e.g., "4,231")
  - Running: distance (e.g., "2.1 km")
  - Cycling: distance (e.g., "5.4 km")
  - Vehicle: distance (e.g., "12.3 km")
- Below each circle: activity label in the activity's color ("walking", "running", "cycling", "driving")
- **Tap a circle** to cycle through metrics: steps → distance → duration → steps...
- Circles appear in order: walking, running, cycling, vehicle (only those that have data today)
- Circles animate in with a gentle scale-up when the view loads
- If no activity yet today, show a single small gray circle with "0" and "steps"

**4. Storyline Timeline** — the main content area, scrollable.

The timeline is a vertical list of alternating **place cards** and **activity segments**, representing the chronological flow of the day.

**Place Card:**
```
┌─────────────────────────────────┐
│  📍 Home                        │
│  8:02 AM – 8:45 AM  · 43 min   │
└─────────────────────────────────┘
```
- Left edge: small colored dot (gray for places)
- Place name in semibold (or address if no name)
- Time range and duration in secondary text
- Tap to open PlaceDetailView

**Activity Segment (between places):**
```
│
│  ● ── 🚶 Walking ──────────────
│       8:45 AM  · 15 min · 1,204 steps
│
```
- A colored vertical line connects from the previous place to the next place
- Line color matches the activity type
- Activity icon (SF Symbol) + label + stats on one line
- Duration, distance, steps (if applicable) on the second line
- The line thickness is ~3pt
- Tap to open ActivityDetailView (shows the route on a map)

**Connected visual structure:**
The timeline should feel like a continuous vertical path. Place cards are "nodes" and activity segments are "edges" between them. Use a continuous vertical line on the left side (inset ~20pt from leading edge) that changes color based on the current activity. Place dots sit on this line.

**If the day is still in progress:**
- The last segment (current activity) has a pulsing dot at the bottom
- If currently at a place, the departure time shows "now" and the duration updates live
- If currently moving, the step count / distance updates live

**If there's no data yet:**
- Show a friendly empty state: "Your day will appear here as you move around."

---

### Screen 2: Activity Detail View

Opened by tapping an activity segment in the timeline. Presented as a sheet (`.sheet` modifier).

**Layout:**
- **Map** at the top (~40% of the screen height) showing the route as a colored polyline on an `MKMapView` (use `Map` in SwiftUI with `MapPolyline`). The map is zoomed to fit the route with padding.
- Start point marked with a small circle, end point with an arrowhead or filled circle.
- Below the map, a **stats card**:
  - Activity type icon + label (e.g., "🚶 Walking")
  - Duration (e.g., "15 minutes")
  - Distance (e.g., "1.2 km")
  - Steps (if walking/running) (e.g., "1,204 steps")
  - Average speed (e.g., "4.8 km/h")
  - Start time → End time (e.g., "8:45 AM → 9:00 AM")

### Screen 3: Place Detail View

Opened by tapping a place card. Presented as a sheet.

**Layout:**
- **Small map** at the top showing the place's pin location
- **Place name** (editable — tap to rename)
- **Address** (from geocoding)
- **Time spent**: arrival → departure, total duration
- **Visit count**: "You've been here 12 times" (query all PlaceVisits at this coordinate cluster)
- **Category badge**: small colored pill showing the place type (Home, Work, Food, etc.) — tappable to change

### Screen 4: Day Map View

Accessible via a small map icon in the top-right corner of StorylineView.

**Layout:**
- Full-screen map showing all routes and places for the selected day
- Routes drawn as colored polylines (color = activity type)
- Places marked with dots
- Semi-transparent overlay at the bottom showing the date and total stats:
  - Total steps, total distance, total active time

### Screen 5: Settings View

Accessible from a gear icon in the top-left corner of StorylineView (or from a minimal menu).

Keep this extremely simple:
- **Distance unit**: km / miles toggle
- **About Traverse**: app version
- **Privacy**: link to iOS Settings (location & motion permissions)

---

## Gesture & Navigation

| Gesture | Action |
|---------|--------|
| Swipe left on main screen | Go to next day (if not today) |
| Swipe right on main screen | Go to previous day |
| Tap activity bubble | Cycle metric: steps → distance → duration |
| Tap timeline activity segment | Open Activity Detail sheet |
| Tap timeline place card | Open Place Detail sheet |
| Tap map icon (top right) | Open Day Map View |
| Tap gear icon (top left) | Open Settings |

---

## Background Tracking Lifecycle

### On First Launch
1. Show a single welcome screen explaining what the app does: "Traverse quietly tracks your daily movement — walks, runs, bike rides, and drives — and shows your day as a storyline."
2. Request Motion permission.
3. Request Location permission (request "Always" via the two-step flow — first request When In Use, then upgrade to Always).
4. Once permissions are granted, start all services (LocationService, MotionService, TimelineEngine).
5. Navigate to StorylineView.

### On Subsequent Launches
1. Check permissions are still granted. If not, show a banner asking the user to re-enable in Settings.
2. Query Core Motion history for any gap since last active timestamp → backfill segments.
3. Resume all services.
4. Display today's storyline.

### While in Background
- Visit monitoring and significant location changes keep running (handled by iOS).
- When woken by a location event, update the current segment, save to SwiftData.
- If woken after a long gap, query Core Motion to fill in what happened.

### On Force Quit / Reboot
- Significant location change monitoring will relaunch the app.
- On relaunch, backfill from Core Motion history.

---

## Key Implementation Details

### Coordinate Storage for Routes
Since `CLLocationCoordinate2D` is not `Codable`, store coordinates as arrays of `CoordinatePoint` objects (latitude, longitude, timestamp) in SwiftData. When drawing on the map, convert back to `CLLocationCoordinate2D`.

### Smooth Activity Transitions
Core Motion can flicker between states. Implement a **debounce** of 10-15 seconds before committing to a new activity type. If the new state doesn't persist for at least 10 seconds, ignore it and keep the current state.

### Distance Calculation
- For walking/running: prefer `CMPedometer` distance (more accurate, uses stride length calibration).
- For cycling/vehicle: calculate distance from GPS coordinates (sum of haversine distances between consecutive breadcrumbs).

### Place Clustering
When determining if a new visit is at a "known" place, compare to all existing places. If the new coordinate is within **80 meters** of an existing place's centroid, treat it as the same place. Update the centroid as the average of all visit coordinates.

### Swipe Navigation Between Days
Use a `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))` or a custom `DragGesture` to swipe between days. Pre-load yesterday and tomorrow's data for smooth transitions. The date range should go back to the first day the app was installed (no future days beyond today).

### Live Updates on Current Day
When viewing today's storyline, use a `Timer` that fires every 5 seconds to update:
- Current segment duration
- Current step count
- Activity bubble sizes and metrics

### Map Route Drawing
Use SwiftUI's `Map` view with `MapPolyline`. For each activity segment that has route coordinates, draw a polyline in the segment's color. Use a stroke width of 4pt with rounded line caps.

### Empty State (Day with No Data)
If the user opens a day before the app was installed, or a day with no data, show:
- The activity bubbles row with a single gray "0 steps" bubble
- A centered message: "No activity recorded for this day."

---

## What NOT to Build

- No social features, no sharing
- No HealthKit integration
- No Apple Watch app
- No widgets (can be added later)
- No onboarding tutorial beyond the single welcome screen
- No gamification, achievements, or streaks
- No calorie calculations
- No weekly/monthly summary views (can be added later)
- No cloud sync or accounts
- No Foursquare or third-party API integration

---

## Build Order (Suggested Phases)

### Phase 1: Data Layer + Services
1. Define all SwiftData models (`TimelineSegment`, `PlaceVisit`, `CoordinatePoint`)
2. Build `LocationService` — permissions, visit monitoring, GPS updates
3. Build `MotionService` — activity detection, pedometer
4. Build `TimelineEngine` — merge location + motion into segments
5. Build `PlaceResolver` — reverse geocoding, basic place naming

### Phase 2: Main UI
6. Build `ColorTheme` and extensions
7. Build `ActivityBubbleView` and `ActivityBubblesRow`
8. Build `TimelineSegmentRow` (both place and activity variants)
9. Build `StorylineView` — assemble bubbles + timeline + day navigation
10. Build `DaySelectorView` — swipe between days

### Phase 3: Detail Views
11. Build `ActivityDetailView` — map + stats
12. Build `PlaceDetailView` — place info + rename
13. Build `DayMapView` — full day route map

### Phase 4: Polish
14. Build welcome/onboarding screen
15. Build `SettingsView`
16. Handle edge cases: no permissions, no data, app backgrounding
17. Battery optimization tuning
18. Animation polish on activity bubbles

---

## Summary

Traverse is a passive, always-on movement tracker that builds a visual storyline of your day. It uses Core Location for where you are, Core Motion for how you're moving, and presents everything in a minimal, beautiful timeline UI inspired by the original Moves app. The user never presses start or stop — they just live their life and open the app to see their day unfold.
