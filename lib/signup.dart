import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart'; // Ensure correct import of login page
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'driver';

  // Add text controllers to capture user input
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _managerKeyController = TextEditingController();

  @override
  void dispose() {
    // Dispose controllers to release memory
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _managerKeyController.dispose();
    super.dispose();
  }

  // Registration core logic method
  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      // If the role is fleet_manager, validate the specific authorization key (e.g., set as "MP")
      if (_selectedRole == 'fleet_manager' && _managerKeyController.text.trim() != 'MP') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Manager Authorization Key! (Hint: MP)'),
            backgroundColor: Color(0xFFBA1A1A),
          ),
        );
        return;
      }

      // Registration success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account registered successfully! Please login.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  // Colors defined according to Tailwind configuration in HTML
  final Color primaryColor = const Color(0xFF3525CD);
  final Color primaryContainer = const Color(0xFF4F46E5);
  final Color surfaceColor = const Color(0xFFF9F9FF);
  final Color surfaceLowest = Colors.white;
  final Color variantColor = const Color(0xFF464555);
  final Color errorColor = const Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111C2D), size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Header Section
                  Text(
                    "FatigueGuard",
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: primaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Create a New Account",
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: variantColor,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surfaceLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.05),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField("FULL NAME", "John Doe", _nameController),
                          _buildTextField("EMAIL", "driver@gmail.com", _emailController, isEmail: true),
                          _buildTextField("PHONE NUMBER", "+60123456789", _phoneController),
                          _buildTextField("PASSWORD", "••••••••", _passwordController, isPassword: true),
                          
                          // Role Select
                          _buildLabel("ROLE"),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            items: const [
                              DropdownMenuItem(value: 'driver', child: Text("Driver")),
                              DropdownMenuItem(value: 'fleet_manager', child: Text("Fleet Manager")),
                            ],
                            onChanged: (val) => setState(() => _selectedRole = val!),
                            decoration: _inputDeco(),
                          ),

                          // Conditional: Manager Authorization Key
                          if (_selectedRole == 'fleet_manager') ...[
                            const SizedBox(height: 16),
                            _buildLabel("MANAGER AUTHORIZATION KEY", color: errorColor),
                            TextFormField(
                              controller: _managerKeyController,
                              obscureText: true,
                              decoration: _inputDeco(hint: "Enter Access Code", isError: true)
                                  .copyWith(
                                    suffixIcon: const Icon(Icons.lock, color: Color(0xFFBA1A1A)),
                                  ),
                              validator: (val) {
                                if (_selectedRole == 'fleet_manager' && (val == null || val.isEmpty)) {
                                  return 'Manager key is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                "RESTRICTED ACCESS FIELD",
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: errorColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Primary Action Button (Bind registration logic)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text("Register Account", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                        ],
                      ),
                    ),
                  ),

                  // Image Decoration Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "SECURE ENROLLMENT",
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF777587),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                  ),

                  // Footer Link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: GoogleFonts.manrope(fontSize: 16, color: variantColor),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          },
                          child: Text(
                            "Login",
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryContainer,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildTextField(String label, String hint, TextEditingController controller, {bool isPassword = false, bool isEmail = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          TextFormField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
            decoration: _inputDeco(hint: hint),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '$label cannot be empty';
              }
              if (isEmail && !value.contains('@')) {
                return 'Please enter a valid email address';
              }
              if (isPassword && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _buildLabel(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color ?? variantColor,
          ),
        ),
      );

  InputDecoration _inputDeco({String? hint, bool isError = false}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isError ? errorColor.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isError ? errorColor : primaryContainer, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
        ),
      );
}