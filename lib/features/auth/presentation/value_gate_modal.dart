import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'email_auth_form.dart';

class ValueGateModal extends StatefulWidget {
  final String title;
  final String description;
  final String targetFeature;
  final AuthService? authService;

  const ValueGateModal({
    super.key,
    this.title = 'Unlock Trailwire Cloud',
    this.description =
        'Create a free account to back up your trail routes, enable GPX export, and arm the off-grid SOS Dead Man\'s Switch.',
    this.targetFeature = 'cloud_feature',
    this.authService,
  });

  /// Static helper to trigger the Value Gate modal bottom sheet
  static Future<bool> show(
    BuildContext context, {
    String title = 'Unlock Trailwire Cloud',
    String description =
        'Create a free account to back up your trail routes, enable GPX export, and arm the off-grid SOS Dead Man\'s Switch.',
    String targetFeature = 'cloud_feature',
    AuthService? authService,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValueGateModal(
        title: title,
        description: description,
        targetFeature: targetFeature,
        authService: authService,
      ),
    );
    return result ?? false;
  }

  @override
  State<ValueGateModal> createState() => _ValueGateModalState();
}

class _ValueGateModalState extends State<ValueGateModal> {
  late final AuthService _authService;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  Future<void> _handleLinkWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.linkWithApple();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _formatAuthError(e);
        });
      }
    }
  }

  Future<void> _handleLinkWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.linkWithGoogle();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _formatAuthError(e);
        });
      }
    }
  }

  Future<void> _handleContinueWithEmail() async {
    final success = await EmailAuthForm.show(
      context,
      authService: _authService,
      initialMode: _authService.isAnonymous ? EmailAuthMode.link : EmailAuthMode.signIn,
    );
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _formatAuthError(dynamic error) {
    final errorString = error.toString();
    if (errorString.contains('credential-already-in-use')) {
      return 'This account is already registered. Please sign in with that account.';
    }
    if (errorString.contains('network-request-failed')) {
      return 'No internet connection detected. Please connect to Wi-Fi or cellular service.';
    }
    return 'Authentication could not be completed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900 dark
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Icon Badge
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: Color(0xFF00E676),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Value Props List
            _buildValueItem(
              icon: Icons.backup_rounded,
              color: const Color(0xFF38BDF8),
              title: 'Seamless Cloud Backup',
              subtitle: 'Your offline trail recordings and waypoints are permanently saved and synced.',
            ),
            const SizedBox(height: 14),
            _buildValueItem(
              icon: Icons.emergency_rounded,
              color: const Color(0xFFEF4444),
              title: 'SOS Dead Man\'s Switch',
              subtitle: 'Automated off-grid safety timers that alert emergency contacts if overdue.',
            ),
            const SizedBox(height: 14),
            _buildValueItem(
              icon: Icons.file_download_rounded,
              color: const Color(0xFFFBBF24),
              title: 'Full GPX & Telemetry Export',
              subtitle: 'Download complete GPS tracklogs with elevation graphs for desktop GIS & Gaia.',
            ),
            const SizedBox(height: 24),

            // Error Display
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

            // Action Buttons
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                    color: Color(0xFF00E676),
                  ),
                ),
              )
            else ...[
              // Sign in with Apple Button
              ElevatedButton.icon(
                onPressed: _handleLinkWithApple,
                icon: const Icon(Icons.apple, size: 24),
                label: const Text(
                  'Sign in with Apple',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 12),

              // Continue with Google Button
              OutlinedButton.icon(
                onPressed: _handleLinkWithGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                label: const Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Continue with Email Button
              OutlinedButton.icon(
                onPressed: _handleContinueWithEmail,
                icon: const Icon(Icons.email_outlined, size: 22, color: Color(0xFF38BDF8)),
                label: const Text(
                  'Continue with Email',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Maybe Later
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Continue Offline as Guest',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildValueItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
