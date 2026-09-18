import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/models/waypoint.dart';
import '../../tracking/services/trail_recording_service.dart';

class WaypointModal extends StatefulWidget {
  final TrailRecordingService recordingService;
  final double? latitude;
  final double? longitude;
  final double? altitude;

  const WaypointModal({
    super.key,
    required this.recordingService,
    this.latitude,
    this.longitude,
    this.altitude,
  });

  static Future<Waypoint?> show(
    BuildContext context, {
    required TrailRecordingService recordingService,
    double? latitude,
    double? longitude,
    double? altitude,
  }) {
    return showModalBottomSheet<Waypoint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WaypointModal(
        recordingService: recordingService,
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
      ),
    );
  }

  @override
  State<WaypointModal> createState() => _WaypointModalState();
}

class _WaypointModalState extends State<WaypointModal> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  String _selectedCategory = 'viewpoint';
  File? _selectedImageFile;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'viewpoint',
      'label': 'Viewpoint',
      'icon': Icons.landscape_rounded,
      'color': Color(0xFFA855F7),
    },
    {
      'id': 'water_source',
      'label': 'Water Source',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF00B0FF),
    },
    {
      'id': 'campsite',
      'label': 'Campsite',
      'icon': Icons.cabin_rounded,
      'color': Color(0xFFFFD600),
    },
    {
      'id': 'hazard',
      'label': 'Hazard',
      'icon': Icons.warning_amber_rounded,
      'color': Color(0xFFFF1744),
    },
    {
      'id': 'trailhead',
      'label': 'Trailhead',
      'icon': Icons.alt_route_rounded,
      'color': Color(0xFF00E676),
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _selectedImageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
    }
  }

  Future<String?> _persistImageLocally(File sourceFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final waypointsDir = Directory('${appDir.path}/waypoints');
      if (!await waypointsDir.exists()) {
        await waypointsDir.create(recursive: true);
      }

      final fileName = 'waypoint_${const Uuid().v4()}.jpg';
      final targetPath = '${waypointsDir.path}/$fileName';
      final savedFile = await sourceFile.copy(targetPath);
      return savedFile.path;
    } catch (e) {
      // ignore: avoid_print
      print('[WaypointModal] Failed to save image locally: $e');
      return sourceFile.path;
    }
  }

  Future<void> _saveWaypoint() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for the waypoint.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? localPhotoPath;
      if (_selectedImageFile != null) {
        localPhotoPath = await _persistImageLocally(_selectedImageFile!);
      }

      final waypoint = await widget.recordingService.addWaypoint(
        title: title,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        category: _selectedCategory,
        localPhotoPath: localPhotoPath,
        latitudeOverride: widget.latitude,
        longitudeOverride: widget.longitude,
        altitudeOverride: widget.altitude,
      );

      if (mounted) {
        Navigator.of(context).pop(waypoint);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save waypoint: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomPadding + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate dark
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mark Waypoint',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (widget.latitude != null && widget.longitude != null)
                  Text(
                    '${widget.latitude!.toStringAsFixed(4)}, ${widget.longitude!.toStringAsFixed(4)}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Category Chips Selector
            const Text(
              'CATEGORY',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['id'];
                  final color = cat['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat['id'];
                          });
                        }
                      },
                      avatar: Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected ? const Color(0xFF0F172A) : color,
                      ),
                      label: Text(
                        cat['label'] as String,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      selectedColor: color,
                      backgroundColor: const Color(0xFF1E293B),
                      side: BorderSide(
                        color: isSelected ? color : const Color(0xFF334155),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Waypoint Title Field
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                hintText: 'e.g. Fresh Spring, Camp Meadow',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF00E676)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Notes / Description Field
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                hintText: 'Observations, water flow rate, campsite capacity...',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF38BDF8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Media Attachment Preview & Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E676),
                      side: const BorderSide(color: Color(0xFF00E676)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedImageFile != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImageFile!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImageFile = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveWaypoint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: const Color(0xFF0B0F12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0B0F12),
                        ),
                      )
                    : const Text(
                        'SAVE WAYPOINT',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
