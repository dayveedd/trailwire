import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum EmailAuthMode {
  link, // Link existing guest account with email/password
  signIn, // Returning user sign-in
  resetPassword, // Password recovery
}

class EmailAuthForm extends StatefulWidget {
  final AuthService? authService;
  final EmailAuthMode initialMode;

  const EmailAuthForm({
    super.key,
    this.authService,
    this.initialMode = EmailAuthMode.link,
  });

  /// Static helper to present EmailAuthForm in a bottom sheet
  static Future<bool> show(
    BuildContext context, {
    AuthService? authService,
    EmailAuthMode initialMode = EmailAuthMode.link,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmailAuthForm(
        authService: authService,
        initialMode: initialMode,
      ),
    );
    return result ?? false;
  }

  @override
  State<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<EmailAuthForm> {
  late final AuthService _authService;
  late EmailAuthMode _mode;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_mode == EmailAuthMode.link) {
        // Link anonymous account preserving local Isar records
        await _authService.linkWithEmailAndPassword(email, password);
        if (mounted) Navigator.of(context).pop(true);
      } else if (_mode == EmailAuthMode.signIn) {
        // Returning user sign-in
        await _authService.signInWithEmailAndPassword(email, password);
        if (mounted) Navigator.of(context).pop(true);
      } else if (_mode == EmailAuthMode.resetPassword) {
        // Send reset email
        await _authService.sendPasswordResetEmail(email);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _successMessage = 'Password reset instructions sent to $email';
          });
        }
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

  String _formatAuthError(dynamic error) {
    final str = error.toString();
    if (str.contains('email-already-in-use') || str.contains('credential-already-in-use')) {
      return 'This email is already associated with an account. Please switch to Sign In.';
    }
    if (str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'Invalid email or password. Please verify your credentials.';
    }
    if (str.contains('user-not-found')) {
      return 'No account found with this email. Please check the address or link a new account.';
    }
    if (str.contains('weak-password')) {
      return 'Password is too weak. Please use at least 6 characters with letters and numbers.';
    }
    if (str.contains('network-request-failed')) {
      return 'Network unavailable. Please check your internet connection.';
    }
    return 'Authentication failed: ${error.toString()}';
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
          top: BorderSide(color: Color(0xFF334155), width: 1.5),
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
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _mode == EmailAuthMode.resetPassword
                          ? Icons.lock_reset_rounded
                          : Icons.mail_lock_rounded,
                      color: const Color(0xFF38BDF8),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  _getTitleText(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  _getSubtitleText(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Status messages
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

                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00E676)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8)),
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
                      borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address.';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password field (only in link & signIn mode)
                if (_mode != EmailAuthMode.resetPassword) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
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
                        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password link (in signIn mode)
                  if (_mode == EmailAuthMode.signIn)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _mode = EmailAuthMode.resetPassword;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // Action button
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: Color(0xFF00E676)),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: const Color(0xFF0B0F12),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      _getButtonText(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Mode toggle
                _buildModeSwitcher(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitleText() {
    switch (_mode) {
      case EmailAuthMode.link:
        return 'Link Email Account';
      case EmailAuthMode.signIn:
        return 'Sign In with Email';
      case EmailAuthMode.resetPassword:
        return 'Reset Password';
    }
  }

  String _getSubtitleText() {
    switch (_mode) {
      case EmailAuthMode.link:
        return 'Protect your offline tracks and enable cloud sync by attaching your email.';
      case EmailAuthMode.signIn:
        return 'Sign in to access your synchronized wilderness routes and waypoints.';
      case EmailAuthMode.resetPassword:
        return 'Enter your email address to receive password recovery instructions.';
    }
  }

  String _getButtonText() {
    switch (_mode) {
      case EmailAuthMode.link:
        return 'Save & Link Account';
      case EmailAuthMode.signIn:
        return 'Sign In';
      case EmailAuthMode.resetPassword:
        return 'Send Reset Link';
    }
  }

  Widget _buildModeSwitcher() {
    if (_mode == EmailAuthMode.resetPassword) {
      return TextButton(
        onPressed: () {
          setState(() {
            _mode = EmailAuthMode.signIn;
            _errorMessage = null;
            _successMessage = null;
          });
        },
        child: const Text(
          'Back to Sign In',
          style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _mode == EmailAuthMode.link
              ? 'Already have an account?'
              : 'Need to link your guest data?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _mode = _mode == EmailAuthMode.link ? EmailAuthMode.signIn : EmailAuthMode.link;
              _errorMessage = null;
              _successMessage = null;
            });
          },
          child: Text(
            _mode == EmailAuthMode.link ? 'Sign In' : 'Link Email',
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
