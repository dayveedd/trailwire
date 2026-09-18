# 🌲 Trailwire

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![iOS Target](https://img.shields.io/badge/iOS-15.0%2B-black?logo=apple&logoColor=white)](https://apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-37%20Passing-brightgreen.svg)]()

**Trailwire** is a high-performance, offline-first, battery-optimized wilderness navigation and logging utility built with Flutter and Native Swift. Engineered specifically for backcountry exploration with zero cellular coverage, Trailwire guarantees that navigation, telemetry recording, waypoint capture, and emergency trip safety work seamlessly off-grid.

---

## 🧭 Core Philosophy

1. **True Offline-First Architecture**: The local database (**Isar**) is the absolute single source of truth. The application UI never blocks or waits on network requests.
2. **Aggressive Wilderness Battery Optimization**: Native CoreLocation platform channels with dynamic distance filtering (`5.0m`), fitness activity classification, and automatic location pauses when stationary preserve battery life on multi-day treks.
3. **Deferred Cloud Synchronization**: Telemetry coordinates, routes, and waypoints are queued locally. When cellular service or Wi-Fi is detected, a deferred sync engine silently uploads data to Cloud Firestore and Firebase Storage.
4. **Zero-Friction Progressive Authentication**: Explorers can immediately open the app and record trails without creating an account (Firebase Anonymous Auth). Account conversion (Google, Apple, Email) uses credential linking so no offline data is ever orphaned.
5. **Wilderness Safety (SOS Dead Man's Switch)**: Set up expected return deadlines, emergency contacts, and trip details. Trips are synchronized to the cloud when online and automatically disarmed when the trek is finished safely.

---

## 📱 User Interface Modes

Trailwire bifurcates the experience into two distinct, clutter-free modes:

```
┌───────────────────────────────────────────────────────────┐
│                      APP LAUNCH                           │
│                           │                               │
│                           ▼                               │
│                   BASECAMP MODE                           │
│   (Map Exploration, Offline Downloader, Style Switcher)   │
│                           │                               │
│                [START TRIP] (Value Gate)                  │
│                           │                               │
│                           ▼                               │
│                    TRAIL MODE                             │
│   (Active GPS HUD, Live Polyline, Mark Pin, SOS Shield)   │
│                           │                               │
│                [FINISH TRIP] (Post-Summary)               │
│                           │                               │
│                           ▼                               │
│                GPX Export & Sync Trigger                  │
└───────────────────────────────────────────────────────────┘
```

### 1. Basecamp Mode (Idle / Planning)
* **Distraction-Free Map View**: Hides live recording telemetry to optimize screen real estate.
* **Vertical Tool Column**: Anchored to the right edge with zero horizontal overflow:
  * 🗺️ **Map Style Toggle**: Seamlessly cycle between Outdoor Topo, Dark Mode, and Satellite imagery.
  * 📥 **Offline Pack Downloader**: Define custom bounding boxes and zoom levels to download vector tile packs for off-grid usage.
  * ☁️ **Cloud Sync**: Trigger manual synchronization with animated status indicator.
  * 🎯 **Recenter**: Recenter the viewport on current GPS coordinates.
* **Prominent "Start Trip" CTA**: Docked at the bottom for quick departure initiation.

### 2. Trail Mode (Active Trekking)
* **High-Contrast Telemetry HUD**: Slide-up dashboard displaying rolling metrics:
  * ⏱️ Elapsed Duration (`HH:MM:SS`)
  * 📏 Distance Travelled (`km` / `mi`)
  * ⛰️ Elevation Gain (`+m`)
  * 🏃 Live Pace (`min/km`)
* **Real-Time Path Rendering**: MapLibre vector polyline renders every recorded coordinate dynamically.
* **One-Tap "Mark Pin" FAB**: Instantly record field waypoints with categories (Camp, Water, Hazard, Viewpoint, Trailhead), custom notes, and local photo attachments.
* **SOS Status Shield**: Displays active check-in safety status and allows viewing emergency contact details.
* **Trip Completion**: Confirms trek conclusion, stops background location services, automatically disarms active SOS alerts, triggers background sync, and presents the GPX summary modal.

---

## 🛠️ Technology Stack

| Layer | Technology | Description |
|---|---|---|
| **UI Framework** | [Flutter](https://flutter.dev) | High-contrast, OLED-friendly dark mode interface |
| **Native GPS Engine** | [Swift / CoreLocation](https://developer.apple.com/documentation/corelocation) | Battery-efficient location streaming via Method & Event channels |
| **Local Database** | [Isar Database](https://isar.dev) | Ultra-fast NoSQL database optimized for coordinate arrays |
| **Mapping Engine** | [MapLibre GL](https://maplibre.org) | Open-source vector tile renderer supporting offline packs |
| **Cloud Backend** | [Firebase](https://firebase.google.com) | Anonymous Auth, Firestore Sync, Cloud Storage |
| **Route Export** | [GPX 1.1 Specification](https://www.topografix.com/gpx.asp) | XML generation with elevation, waypoints, and native OS share sheets |
| **In-App Purchases** | [RevenueCat](https://www.revenuecat.com) | Topo layer access and cloud SOS tier management |

---

## 📂 Project Architecture

```
lib/
├── core/
│   ├── database/
│   │   ├── isar_service.dart              # Isar lifecycle, dual-key UUID schemas
│   │   └── models/
│   │       ├── coordinate.dart            # Lat, Lng, Alt, Speed, Heading, Accuracy
│   │       ├── trail_route.dart           # Route metadata, telemetry, sync flags
│   │       └── waypoint.dart              # Coordinates, photo paths, categories
│   ├── models/
│   │   └── location_data.dart             # Standardized internal location model
│   ├── platform/
│   │   └── location_channel.dart          # Native Swift CoreLocation MethodChannel & EventChannel
│   └── utils/
│       └── geo_utils.dart                 # Haversine distance, speed, and elevation calculations
├── features/
│   ├── auth/
│   │   ├── presentation/
│   │   │   ├── email_auth_form.dart       # Email/Password link & sign-in forms
│   │   │   └── value_gate_modal.dart      # Contextual benefit modals for cloud features
│   │   └── services/
│   │       └── auth_service.dart          # Anonymous auth, linkWithCredential, account deletion
│   ├── export/
│   │   └── services/
│   │       └── gpx_service.dart           # GPX 1.1 XML generation, file storage & share integration
│   ├── map/
│   │   ├── presentation/
│   │   │   ├── trail_hud.dart             # Basecamp & Trail Mode overlays with responsive design
│   │   │   └── trail_map_view.dart        # MapLibre GL widget, puck tracking & polylines
│   │   └── services/
│   │       └── offline_map_service.dart   # Region tile pack downloads & cache management
│   ├── safety/
│   │   ├── models/
│   │   │   └── sos_trip.dart              # Safety check-in models & Firestore mapping
│   │   └── presentation/
│   │       └── sos_trip_setup_view.dart   # SOS trip deadline config & emergency contact setup
│   ├── sync/
│   │   ├── models/
│   │   │   └── sync_result.dart           # Synchronization telemetry & report summaries
│   │   └── services/
│   │       └── sync_service.dart          # Deferred Firestore & Storage sync with connectivity listener
│   ├── tracking/
│   │   ├── models/
│   │   │   └── app_mode.dart              # enum AppMode { basecamp, activeTracking }
│   │   ├── presentation/
│   │   │   └── trail_screen.dart          # Main map coordinator, mode switching & lifecycle
│   │   └── services/
│   │       ├── location_service.dart      # Flutter location wrapper
│   │       └── trail_recording_service.dart # Telemetry recording, filtering, Isar batch persistence
│   └── waypoints/
│       └── presentation/
│           └── waypoint_modal.dart        # Field waypoint tagging & photo capture sheet
└── main.dart                              # Application initialization & theme setup
```

---

## ⚡ Battery Optimization Details

Wilderness tracking presents extreme battery constraints. Trailwire adopts several battery-saving strategies:

* **Hardware Distance Filter**: Uses a `5.0m` displacement threshold in native Swift CoreLocation so GPS hardware does not wake the CPU when stationary.
* **Fitness Activity Profile**: Configures `activityType = .fitness` allowing iOS to optimize accelerometer and gyroscope integration for pedestrian trail movements.
* **Automatic Pause**: Enables `pausesLocationUpdatesAutomatically = true` to allow hardware sleep during extended rest stops.
* **OLED Deep Blacks**: UI utilizes `#0B0F12` and `#0F172A` palettes to minimize display power draw on OLED mobile screens.

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19+ recommended)
* [Xcode](https://developer.apple.com/xcode/) 15.0+ (for iOS builds)
* [CocoaPods](https://cocoapods.org/) 1.15+

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/dayveedd/trailwire.git
   cd trailwire
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Install iOS CocoaPods**:
   ```bash
   cd ios
   pod install
   cd ..
   ```

4. **Run Code Generation (Isar)**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

### Firebase Setup (Optional for Local Off-Grid Testing)
Trailwire runs completely offline out-of-the-box using the local Isar database. To enable cloud sync and SOS alerts:
1. Create a Firebase project at the [Firebase Console](https://console.firebase.google.com).
2. Configure **Authentication** (enable Anonymous, Google, Apple, and Email/Password).
3. Provision **Cloud Firestore** and **Firebase Storage**.
4. Generate `lib/firebase_options.dart` using the FlutterFire CLI:
   ```bash
   flutterfire configure
   ```
5. Place `GoogleService-Info.plist` into `ios/Runner/` and `google-services.json` into `android/app/`.

### Run the App
```bash
flutter run
```

---

## 🧪 Testing & Verification

The codebase includes full automated test coverage for data models, GPX generation, widget HUD states, and platform channels:

```bash
# Run static analysis
dart analyze

# Run all automated tests
flutter test
```

### Key Test Suites
* `test/app_mode_test.dart` - Mode transitions and state integrity.
* `test/trail_hud_test.dart` - HUD layout rendering, narrow-screen overflow assertions, and action callbacks.
* `test/gpx_service_test.dart` - Spec-compliant GPX 1.1 XML validation, elevation tags, and entity escaping.
* `test/sos_trip_test.dart` - Safety trip model serialization and setup view validation.
* `test/database_models_test.dart` - Dual-key UUID schemas and Isar model persistence.
* `test/location_channel_test.dart` - Method and Event channel mock verifications.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
