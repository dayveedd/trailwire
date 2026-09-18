import Flutter
import UIKit
import CoreLocation

enum TrackingState: String {
  case stopped
  case tracking
  case paused
}

public class LocationTrackingManager: NSObject, CLLocationManagerDelegate, FlutterStreamHandler {
  static let shared = LocationTrackingManager()

  private let methodChannelName = "com.trailwire/location"
  private let eventChannelName = "com.trailwire/location_stream"
  private let legacyMethodChannelName = "com.usetrailwire.trailwire/location"
  private let legacyEventChannelName = "com.usetrailwire.trailwire/location_stream"

  private var locationManager: CLLocationManager?
  private var trackingState: TrackingState = .stopped
  private var currentRouteId: String?
  private var eventSink: FlutterEventSink?

  private let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  override init() {
    super.init()
    setupLocationManager()
  }

  private func setupLocationManager() {
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    // High accuracy navigation mode for wilderness trail fidelity
    locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    // 5.0m distance filter prevents continuous GPS polling when hiker is stationary, preserving battery
    locationManager?.distanceFilter = 5.0
    // Fitness activity type optimizes hardware GPS heuristics for hiking/walking speeds
    locationManager?.activityType = .fitness
    // Explicitly set to false so iOS does not silently kill tracking during long rest stops or deep backcountry treks
    locationManager?.pausesLocationUpdatesAutomatically = false
    if #available(iOS 11.0, *) {
      locationManager?.showsBackgroundLocationIndicator = true
    }
  }

  public func register(with messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    let legacyMethodChannel = FlutterMethodChannel(name: legacyMethodChannelName, binaryMessenger: messenger)

    let handler: FlutterMethodCallHandler = { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      self?.handle(call: call, result: result)
    }

    methodChannel.setMethodCallHandler(handler)
    legacyMethodChannel.setMethodCallHandler(handler)

    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    let legacyEventChannel = FlutterEventChannel(name: legacyEventChannelName, binaryMessenger: messenger)

    eventChannel.setStreamHandler(self)
    legacyEventChannel.setStreamHandler(self)
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startTracking":
      let args = call.arguments as? [String: Any]
      let routeId = args?["routeId"] as? String ?? UUID().uuidString
      let distanceFilter = args?["distanceFilter"] as? Double ?? 5.0
      startTracking(routeId: routeId, distanceFilter: distanceFilter, result: result)

    case "pauseTracking":
      pauseTracking(result: result)

    case "stopTracking":
      stopTracking(result: result)

    case "isTracking":
      result(trackingState == .tracking)

    case "getTrackingState":
      result(trackingState.rawValue)

    case "getCurrentLocation":
      if let location = locationManager?.location {
        result(locationToDictionary(location: location))
      } else {
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func startTracking(routeId: String, distanceFilter: Double, result: @escaping FlutterResult) {
    guard let manager = locationManager else {
      result(FlutterError(code: "UNAVAILABLE", message: "LocationManager is not initialized", details: nil))
      return
    }

    currentRouteId = routeId
    manager.distanceFilter = distanceFilter

    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }

    if status == .notDetermined {
      manager.requestAlwaysAuthorization()
    }

    // Enable background updates for seamless background trail logging
    manager.allowsBackgroundLocationUpdates = true
    manager.pausesLocationUpdatesAutomatically = false
    manager.startUpdatingLocation()
    trackingState = .tracking
    result(true)
  }

  public func pauseTracking(result: @escaping FlutterResult) {
    guard let manager = locationManager else {
      result(false)
      return
    }

    manager.stopUpdatingLocation()
    trackingState = .paused
    result(true)
  }

  public func stopTracking(result: @escaping FlutterResult) {
    guard let manager = locationManager else {
      result(false)
      return
    }

    manager.stopUpdatingLocation()
    manager.allowsBackgroundLocationUpdates = false
    trackingState = .stopped
    currentRouteId = nil
    result(true)
  }

  // MARK: - CLLocationManagerDelegate

  public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard trackingState == .tracking else { return }

    for location in locations {
      // Reject invalid or outdated cached locations (> 15 seconds old)
      if abs(location.timestamp.timeIntervalSinceNow) > 15.0 {
        continue
      }
      // Filter out points with horizontal accuracy worse than 50 meters
      if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 50.0 {
        continue
      }

      let payload = locationToDictionary(location: location)
      eventSink?(payload)
    }
  }

  public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("[Trailwire] CoreLocation error: \(error.localizedDescription)")
  }

  private func locationToDictionary(location: CLLocation) -> [String: Any] {
    return [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "altitude": location.altitude,
      "speed": location.speed >= 0 ? location.speed : 0.0,
      "heading": location.course >= 0 ? location.course : 0.0,
      "accuracy": location.horizontalAccuracy,
      "timestamp": isoFormatter.string(from: location.timestamp),
      "routeId": currentRouteId ?? ""
    ]
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      LocationTrackingManager.shared.register(with: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
