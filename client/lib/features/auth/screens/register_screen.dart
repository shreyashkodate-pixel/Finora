import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../providers/auth_provider.dart';

/// Enterprise Registration Screen with Role and Site selection per SRS §3.3a.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _siteController = TextEditingController(text: 'HQ Campus');

  String _selectedRole = 'requester';
  bool _obscurePassword = true;

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

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
      site: _siteController.text.trim().isNotEmpty ? _siteController.text.trim() : null,
    );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Helpdesk Account'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Register Account',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select your organizational role to configure permissions',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(height: 24),

                      // Error Banner
                      if (auth.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.priorityP1.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.priorityP1.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: AppColors.priorityP1, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Work Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email is required.';
                          if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password (min 8 characters)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Password is required.';
                          if (val.length < 8) return 'Password must be at least 8 characters.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Role Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'System Role',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: _roles.map((r) {
                          return DropdownMenuItem(
                            value: r['value'],
                            child: Text(r['label']!),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Site / Campus Field
                      TextFormField(
                        controller: _siteController,
                        decoration: const InputDecoration(
                          labelText: 'Office Site / Campus Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      AccessibleButton(
                        onPressed: _handleRegister,
                        isLoading: auth.isLoading,
                        semanticLabel: 'Complete registration button',
                        child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),

                      // Back to login
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Already registered? Back to Sign In'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
