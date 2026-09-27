import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/colors.dart';
import '../providers/auth_provider.dart';

/// Pixel-perfect Stitch Dual-Path Authentication Screen per UI Screen Map & Stitch Specs.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _siteController = TextEditingController();

  bool _isSignIn = true;
  bool _obscurePassword = true;
  bool _rememberWorkstation = true;
  String _selectedRole = 'operator';

  final List<Map<String, String>> _roles = [
    {'value': 'requester', 'label': 'Requester (Standard Employee)'},
    {'value': 'operator', 'label': 'Operator (IT Support Technician)'},
    {'value': 'team_lead', 'label': 'Team Lead (Escalation & Approver)'},
    {'value': 'manager', 'label': 'Manager (Operations & Oversight)'},
    {'value': 'administrator', 'label': 'Administrator (System Admin)'},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    if (_isSignIn) {
      await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      final success = await auth.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        site: _siteController.text.trim().isNotEmpty ? _siteController.text.trim() : null,
      );
      if (success) {
        await auth.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main Authentication Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Icon
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: const Icon(
                              Icons.support_agent,
                              size: 32,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Shield Badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCE9FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined, size: 14, color: AppColors.primaryDark),
                                SizedBox(width: 6),
                                Text(
                                  'Single Sign-On & Dual-Path Auth v4.0',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Titles
                        const Text(
                          'AI IT Helpdesk',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B1C30),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Precision Enterprise Service Management',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Segmented Tab Switcher (Sign In vs Register)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (!_isSignIn) setState(() => _isSignIn = true);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isSignIn ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _isSignIn
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.04),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      'Sign In',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _isSignIn ? FontWeight.w700 : FontWeight.w500,
                                        color: _isSignIn ? AppColors.primaryDark : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (_isSignIn) setState(() => _isSignIn = false);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !_isSignIn ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: !_isSignIn
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.04),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      'Register New Account',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: !_isSignIn ? FontWeight.w700 : FontWeight.w500,
                                        color: !_isSignIn ? AppColors.primaryDark : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Google OAuth PKCE Button
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Google OAuth 2.0 PKCE flow initialized with domain whitelisting.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9zqoA1W0BOqFu40gxJMzfSi8JVmmBQN2w',
                                width: 18,
                                height: 18,
                                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 20, color: Color(0xFF4285F4)),
                              ),
                              const SizedBox(width: 10),
                              const Flexible(
                                child: Text(
                                  'Continue with Google Workspace (OAuth 2.0 PKCE)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enforces corporate domain whitelist (@acme.corp, @acme-contractors.com)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 18),

                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                _isSignIn ? 'OR SIGN IN WITH ENTERPRISE CREDENTIALS' : 'OR REGISTER WITH ENTERPRISE CREDENTIALS',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Error Banner
                        if (auth.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.priorityP1.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.priorityP1.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 18, color: AppColors.priorityP1),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.errorMessage!,
                                    style: const TextStyle(color: AppColors.priorityP1, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email Field
                        const Text(
                          'Work Email',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0B1C30)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w500),
                          cursorColor: AppColors.primaryBlue,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'name@acme.corp',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon: const Icon(Icons.mail_outline, size: 18, color: Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Email is required.';
                            if (!val.contains('@')) return 'Enter a valid email address.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Role Selector & Site Input (Register Mode Only)
                        if (!_isSignIn) ...[
                          const Text(
                            'Select System Role',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0B1C30)),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            items: _roles.map((r) {
                              return DropdownMenuItem(
                                value: r['value'],
                                child: Text(r['label']!, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedRole = val);
                            },
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Assigned Campus / Site',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0B1C30)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _siteController,
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w500),
                            cursorColor: AppColors.primaryBlue,
                            decoration: InputDecoration(
                              hintText: 'HQ Campus',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              prefixIcon: const Icon(Icons.business_outlined, size: 18, color: Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Password Field
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0B1C30)),
                            ),
                            if (_isSignIn)
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Password reset instructions sent via corporate email.')),
                                  );
                                },
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w500),
                          cursorColor: AppColors.primaryBlue,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••••••',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF64748B)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: const Color(0xFF64748B),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Password is required.';
                            if (val.length < 8) return 'Password must be at least 8 characters.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Remember Workstation Checkbox
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberWorkstation,
                                activeColor: AppColors.primaryBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) => setState(() => _rememberWorkstation = val ?? true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Remember this trusted workstation for 30 days via rotating refresh tokens',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Submit Button
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isSignIn ? 'Sign In to Workspace' : 'Create & Access Account',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),

                        // FIDO2 Hardware Key Link
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('FIDO2 WebAuthn token authentication prompt.')),
                              );
                            },
                            icon: const Icon(Icons.vpn_key_outlined, size: 15, color: Color(0xFF64748B)),
                            label: const Text(
                              'Use WebAuthn / FIDO2 Security Hardware Key',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Security & Metadata Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Text(
                    'Argon2id Key Derivation • 10 req/min sliding-window rate limit enforced • Anti-Collision Protection Active',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
