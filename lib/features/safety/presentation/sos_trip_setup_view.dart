import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../auth/services/auth_service.dart';
import '../models/sos_trip.dart';

class SosTripSetupView extends StatefulWidget {
  final AuthService? authService;
  final FirebaseFirestore? firestore;
  final String? initialTripName;
  final double? currentLatitude;
  final double? currentLongitude;

  const SosTripSetupView({
    super.key,
    this.authService,
    this.firestore,
    this.initialTripName,
    this.currentLatitude,
    this.currentLongitude,
  });

  /// Static helper to open the SOS Trip setup modal
  static Future<SosTrip?> show(
    BuildContext context, {
    AuthService? authService,
    FirebaseFirestore? firestore,
    String? initialTripName,
    double? currentLatitude,
    double? currentLongitude,
  }) async {
    final result = await showModalBottomSheet<SosTrip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SosTripSetupView(
        authService: authService,
        firestore: firestore,
        initialTripName: initialTripName,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
      ),
    );
    return result;
  }

  @override
  State<SosTripSetupView> createState() => _SosTripSetupViewState();
}

class _SosTripSetupViewState extends State<SosTripSetupView> {
  AuthService get _authService => widget.authService ?? AuthService();
  FirebaseFirestore get _firestore => widget.firestore ?? FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _intentController = TextEditingController();
  final _contactController = TextEditingController();

  DateTime _expectedReturn = DateTime.now().add(const Duration(hours: 4));
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final defaultName = widget.initialTripName ??
        'Hike ${DateTime.now().month}/${DateTime.now().day}';
    _nameController.text = defaultName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _expectedReturn.isAfter(now) ? _expectedReturn : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFEF4444),
            onPrimary: Colors.white,
            surface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      setState(() {
        _expectedReturn = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _expectedReturn.hour,
          _expectedReturn.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedReturn),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFEF4444),
            onPrimary: Colors.white,
            surface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );

    if (pickedTime != null) {
      setState(() {
        _expectedReturn = DateTime(
          _expectedReturn.year,
          _expectedReturn.month,
          _expectedReturn.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _applyQuickOffset(Duration duration) {
    setState(() {
      _expectedReturn = DateTime.now().add(duration);
    });
  }

  Future<void> _handleArmTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_expectedReturn.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      setState(() {
        _errorMessage = 'Expected return time must be at least 5 minutes in the future.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Obtain user ID (or initialize guest UID)
      var userId = _authService.currentUserId;
      if (userId == null) {
        final guest = await _authService.initializeGuestAuth();
        userId = guest?.uid;
      }

      if (userId == null) {
        throw StateError('Authentication is required to arm an SOS safety trip.');
      }

      final tripId = const Uuid().v4();
      final now = DateTime.now();

      final sosTrip = SosTrip(
        tripId: tripId,
        userId: userId,
        tripName: _nameController.text.trim(),
        routeIntent: _intentController.text.trim().isNotEmpty
            ? _intentController.text.trim()
            : null,
        emergencyContact: _contactController.text.trim(),
        expectedReturnTime: _expectedReturn,
        status: 'ACTIVE',
        createdAt: now,
        lastKnownLatitude: widget.currentLatitude,
        lastKnownLongitude: widget.currentLongitude,
      );

      // Push to Firestore collection 'sos_trips'
      await _firestore
          .collection('sos_trips')
          .doc(tripId)
          .set(sosTrip.toFirestore());

      if (mounted) {
        Navigator.of(context).pop(sosTrip);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to arm SOS Trip: ${e.toString()}';
        });
      }
    }
  }

  String _formatReturnDateTime() {
    final now = DateTime.now();
    final isToday = _expectedReturn.year == now.year &&
        _expectedReturn.month == now.month &&
        _expectedReturn.day == now.day;

    final hour = _expectedReturn.hour.toString().padLeft(2, '0');
    final minute = _expectedReturn.minute.toString().padLeft(2, '0');
    final dateStr = isToday
        ? 'Today'
        : '${_expectedReturn.month}/${_expectedReturn.day}';

    final diff = _expectedReturn.difference(now);
    final hoursRemaining = diff.inHours;
    final minsRemaining = diff.inMinutes % 60;
    final inStr = diff.isNegative
        ? 'overdue'
        : 'in ${hoursRemaining}h ${minsRemaining}m';

    return '$dateStr at $hour:$minute ($inStr)';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFFEF4444), width: 2.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFEF4444),
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                const Text(
                  'SOS Dead Man\'s Switch',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                const Text(
                  'If you do not return and disarm this safety timer before the deadline, your emergency contact will be sent your planned route intent and last known GPS coordinates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Trip Name Field
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Trip Name',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.hiking_rounded, color: Color(0xFFEF4444)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a trip name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Emergency Contact Phone Field
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Emergency Contact Phone',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFEF4444)),
                    hintText: '+1 (555) 019-2834',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an emergency contact phone number.';
                    }
                    if (value.trim().length < 7) {
                      return 'Please enter a valid phone number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Route Intent / Description Field
                TextFormField(
                  controller: _intentController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Route Intent & Vehicle Description',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    hintText: 'e.g. Mist Trail to Half Dome cables, parked in silver Subaru at trailhead',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFFEF4444)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Expected Return Time Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'EXPECTED RETURN TIME',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DEADLINE',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatReturnDateTime(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pick Date and Time buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: const Text('Change Date'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF475569)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.access_time_rounded, size: 16),
                              label: const Text('Change Time'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF475569)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Quick preset pills
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('+2h'),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                            onPressed: () => _applyQuickOffset(const Duration(hours: 2)),
                          ),
                          ActionChip(
                            label: const Text('+4h'),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                            onPressed: () => _applyQuickOffset(const Duration(hours: 4)),
                          ),
                          ActionChip(
                            label: const Text('+8h'),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                            onPressed: () => _applyQuickOffset(const Duration(hours: 8)),
                          ),
                          ActionChip(
                            label: const Text('+24h'),
                            backgroundColor: const Color(0xFF0F172A),
                            labelStyle: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                            onPressed: () => _applyQuickOffset(const Duration(hours: 24)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Arm Trip Button
                if (_isSubmitting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: Color(0xFFEF4444)),
                    ),
                  )
                else ...[
                  ElevatedButton.icon(
                    onPressed: _handleArmTrip,
                    icon: const Icon(Icons.shield_rounded, size: 20),
                    label: const Text(
                      'ARM SOS TRIP & START HIKE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Skip / Disarm button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text(
                      'Cancel / Continue Without SOS',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
