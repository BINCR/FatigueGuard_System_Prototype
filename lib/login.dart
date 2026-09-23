import 'package:flutter/material.dart';
import 'driver_home.dart';
import 'fleet_manager_dashboard.dart';
import 'forgot_password.dart';
import 'signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  static const Color primaryColor = Color(0xFF3525CD);
  static const Color backgroundColor = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF464555);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color outlineVariant = Color(0xFFC7C4D8);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email == 'rb713@gmail.com' && password == '1234567890') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriverHomePage()),
      );
    } else if (email == 'manager@gmail.com' && password == '1234567890') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const FleetManagerDashboardPage(),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Login Failed',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Incorrect username or password. Please try again.\n\nHint:\nDriver: rb713@gmail.com / 1234567890\nManager: manager@gmail.com / 1234567890',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'FatigueGuard',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Driver Fatigue & Safety Monitoring',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      color: onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: outlineVariant.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'EMAIL ADDRESS',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            fontSize: 16,
                            color: onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'driver@gmail.com',
                            hintStyle: TextStyle(
                              color: onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            prefixIcon: const Icon(
                              Icons.mail_outline,
                              color: onSurfaceVariant,
                            ),
                            filled: true,
                            fillColor: surfaceContainerLow,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18.0,
                              horizontal: 16.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'PASSWORD',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            fontSize: 16,
                            color: onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: TextStyle(
                              color: onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: onSurfaceVariant,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: surfaceContainerLowest,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18.0,
                              horizontal: 16.0,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot your password?',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Manrope',
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  color: onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Biometric authentication is not configured.',
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: surfaceContainerLow,
                            foregroundColor: onSurfaceVariant,
                            minimumSize: const Size(double.infinity, 56),
                            side: BorderSide(
                              color: outlineVariant.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fingerprint,
                                size: 24,
                                color: primaryColor,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Sign in with Biometrics',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: onSurfaceVariant, fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
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
