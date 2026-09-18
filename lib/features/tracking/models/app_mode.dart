/// Operational mode of the Trailwire navigation engine.
enum AppMode {
  /// Default state on app launch: Map exploration, offline pack caching, cloud sync, and pre-trip planning.
  basecamp,

  /// Active state: Background GPS recording, live telemetry HUD, waypoint pin capture, and SOS monitoring.
  activeTracking,
}
