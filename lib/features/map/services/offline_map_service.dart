import 'dart:convert';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

class OfflineMapService {
  /// CARTO Voyager: Rich outdoor topography and trails vector tiles up to zoom 20
  static const String outdoorStyleUrl =
      'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';

  /// CARTO Dark Matter: Low-light tactical battery saver vector style
  static const String darkStyleUrl =
      'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';

  /// Default map style for wilderness tracking (Outdoor Topo)
  static const String defaultStyleUrl = outdoorStyleUrl;

  /// Download and cache an offline map pack for a given geographic bounding box.
  static Future<maplibre.OfflineRegion?> downloadOfflineRegion({
    required maplibre.LatLngBounds bounds,
    required String regionName,
    String styleUrl = defaultStyleUrl,
    double minZoom = 10.0,
    double maxZoom = 16.0,
    Function(maplibre.DownloadRegionStatus)? onProgress,
  }) async {
    try {
      final definition = maplibre.OfflineRegionDefinition(
        bounds: bounds,
        mapStyleUrl: styleUrl,
        minZoom: minZoom,
        maxZoom: maxZoom,
      );

      final metadata = <String, dynamic>{
        'name': regionName,
        'createdAt': DateTime.now().toIso8601String(),
        'bounds': [
          bounds.southwest.latitude,
          bounds.southwest.longitude,
          bounds.northeast.latitude,
          bounds.northeast.longitude,
        ],
      };

      final region = await maplibre.downloadOfflineRegion(
        definition,
        metadata: metadata,
        onEvent: onProgress,
      );
      return region;
    } catch (e) {
      // ignore: avoid_print
      print('[OfflineMapService] Error downloading offline region: $e');
      return null;
    }
  }

  /// List all locally downloaded offline regions.
  static Future<List<maplibre.OfflineRegion>> getDownloadedRegions() async {
    try {
      return await maplibre.getListOfRegions();
    } catch (e) {
      // ignore: avoid_print
      print('[OfflineMapService] Error fetching offline regions: $e');
      return [];
    }
  }

  /// Delete an offline region by its ID.
  static Future<void> deleteOfflineRegion(int id) async {
    try {
      await maplibre.deleteOfflineRegion(id);
    } catch (e) {
      // ignore: avoid_print
      print('[OfflineMapService] Error deleting offline region $id: $e');
    }
  }

  /// Helper to extract region name from metadata
  static String getRegionName(maplibre.OfflineRegion region) {
    try {
      final metadata = region.metadata;
      if (metadata.containsKey('name')) {
        return metadata['name'] as String;
      }
      if (metadata.containsKey('metadata')) {
        final decoded = jsonDecode(metadata['metadata']);
        return decoded['name'] ?? 'Region #${region.id}';
      }
    } catch (_) {}
    return 'Region #${region.id}';
  }
}
