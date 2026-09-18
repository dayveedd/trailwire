import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'models/trail_route.dart';
import 'models/coordinate.dart';
import 'models/waypoint.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  Isar? _isar;

  Future<Isar> get db async {
    if (_isar != null && _isar!.isOpen) {
      return _isar!;
    }
    _isar = await openDatabase();
    return _isar!;
  }

  Future<Isar> openDatabase() async {
    if (Isar.instanceNames.isNotEmpty) {
      final existing = Isar.getInstance();
      if (existing != null && existing.isOpen) {
        return existing;
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [
        TrailRouteSchema,
        CoordinateSchema,
        WaypointSchema,
      ],
      directory: dir.path,
      inspector: true,
    );
  }

  /// Query all unsynced routes
  Future<List<TrailRoute>> getUnsyncedRoutes() async {
    final isar = await db;
    return await isar.trailRoutes.filter().isSyncedEqualTo(false).findAll();
  }

  /// Query all unsynced coordinates for batch sync
  Future<List<Coordinate>> getUnsyncedCoordinates({int limit = 500}) async {
    final isar = await db;
    return await isar.coordinates.filter().isSyncedEqualTo(false).limit(limit).findAll();
  }

  /// Query all unsynced waypoints
  Future<List<Waypoint>> getUnsyncedWaypoints() async {
    final isar = await db;
    return await isar.waypoints.filter().isSyncedEqualTo(false).findAll();
  }

  /// Query all coordinates belonging to a specific route ordered chronologically
  Future<List<Coordinate>> getCoordinatesForRoute(String routeId) async {
    final isar = await db;
    return await isar.coordinates
        .filter()
        .routeIdEqualTo(routeId)
        .sortByTimestamp()
        .findAll();
  }

  /// Query all waypoints belonging to a specific route ordered chronologically
  Future<List<Waypoint>> getWaypointsForRoute(String routeId) async {
    final isar = await db;
    return await isar.waypoints
        .filter()
        .routeIdEqualTo(routeId)
        .sortByTimestamp()
        .findAll();
  }

  /// Query all completed routes ordered by start time descending
  Future<List<TrailRoute>> getAllCompletedRoutes() async {
    final isar = await db;
    return await isar.trailRoutes
        .filter()
        .statusEqualTo('completed')
        .sortByStartTimeDesc()
        .findAll();
  }

  /// Query all saved waypoints across all treks ordered by timestamp descending
  Future<List<Waypoint>> getAllWaypoints() async {
    final isar = await db;
    return await isar.waypoints.where().sortByTimestampDesc().findAll();
  }

  /// Delete a route and all associated coordinates and waypoints
  Future<void> deleteRoute(String routeId) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.trailRoutes.filter().routeIdEqualTo(routeId).deleteAll();
      await isar.coordinates.filter().routeIdEqualTo(routeId).deleteAll();
      await isar.waypoints.filter().routeIdEqualTo(routeId).deleteAll();
    });
  }

  /// Delete a single waypoint
  Future<void> deleteWaypoint(String waypointId) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.waypoints.filter().waypointIdEqualTo(waypointId).deleteAll();
    });
  }

  /// Close the database instance (e.g. for testing or app teardown)
  Future<void> close() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
      _isar = null;
    }
  }
}
