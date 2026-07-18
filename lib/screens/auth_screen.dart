import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import 'map_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoginMode = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  void _showSnackBar(String title, String body, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rubik'),
              textAlign: TextAlign.right,
            ),
            Text(
              body,
              style: const TextStyle(fontSize: 12, fontFamily: 'Rubik'),
              textAlign: TextAlign.right,
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabaseService = Provider.of<SupabaseService>(context, listen: false);

    try {
      if (_isLoginMode) {
        // Run Sign In
        await supabaseService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        _showSnackBar("مرحباً بعودتك!", "تم تسجيل الدخول بنجاح.");
      } else {
        // Signup validation
        final usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');
        final uname = _usernameController.text.trim().toLowerCase();
        if (!usernamePattern.hasMatch(uname)) {
          throw Exception("اسم المستخدم: 3-20 حرف، أحرف إنجليزية وأرقام و _ فقط");
        }

        // Run Sign Up
        await supabaseService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          username: uname,
          department: _deptController.text.trim(),
          redirectUrl: "https://uot-cs.lovable.app/", // Web compatibility
        );
        _showSnackBar("تم إنشاء الحساب بنجاح!", "أهلاً بك في الحرم الذكي.");
      }

      // Navigate to Map Dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }
    } catch (err) {
      String rawMessage = err.toString();
      String friendlyMessage = rawMessage;
      if (rawMessage.contains("Invalid login")) {
        friendlyMessage = "البريد الإلكتروني أو كلمة المرور غير صحيحة";
      } else if (rawMessage.contains("already registered")) {
        friendlyMessage = "هذا البريد مسجّل مسبقاً، حاول تسجيل الدخول";
      } else if (rawMessage.contains("Password should")) {
        friendlyMessage = "كلمة المرور قصيرة جداً (الحد ٦ أحرف)";
      }
      _showSnackBar("فشلت العملية", friendlyMessage, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient matching auth.tsx
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E3A8A), // Rich Navy
                  Color(0xFF3B82F6), // Vibrant Blue
                  Color(0xFF0F172A), // Dark Slate
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Top Header
                      Container(
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "الحرم الذكي",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "الجامعة التكنولوجية - بغداد",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      // Main Form Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Tab Selector
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isLoginMode = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _isLoginMode ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: _isLoginMode
                                              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)]
                                              : null,
                                        ),
                                        child: Text(
                                          "تسجيل الدخول",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _isLoginMode ? Colors.black87 : Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isLoginMode = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: !_isLoginMode ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: !_isLoginMode
                                              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)]
                                              : null,
                                        ),
                                        child: Text(
                                          "حساب جديد",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: !_isLoginMode ? Colors.black87 : Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Fields
                            if (!_isLoginMode) ...[
                              _buildTextField(
                                controller: _fullNameController,
                                label: "الاسم الكامل",
                                placeholder: "مثال: أحمد علي",
                                icon: Icons.person_outline,
                                validator: (val) => val == null || val.isEmpty ? "الاسم مطلوب" : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _usernameController,
                                label: "اسم المستخدم (فريد)",
                                placeholder: "ahmad_ali",
                                icon: Icons.alternate_email,
                                isLtr: true,
                                validator: (val) => val == null || val.isEmpty ? "اسم المستخدم مطلوب" : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _deptController,
                                label: "القسم العلمي",
                                placeholder: "مثال: هندسة الحاسوب",
                                icon: Icons.school_outlined,
                                validator: (val) => val == null || val.isEmpty ? "القسم مطلوب" : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildTextField(
                              controller: _emailController,
                              label: "البريد الإلكتروني",
                              placeholder: "student@uotechnology.edu.iq",
                              icon: Icons.mail_outline,
                              isLtr: true,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.isEmpty) return "البريد مطلوب";
                                if (!val.contains("@")) return "البريد غير صالح";
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: "كلمة المرور",
                              placeholder: "••••••",
                              icon: Icons.lock_outline,
                              obscureText: true,
                              validator: (val) {
                                if (val == null || val.isEmpty) return "كلمة المرور مطلوبة";
                                if (val.length < 6) return "قصيرة جداً (الحد ٦ أحرف)";
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            // Submit Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isLoginMode ? "دخول" : "إنشاء الحساب",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Skip Back to Home Visual CTA
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const MapScreen()),
                          );
                        },
                        child: Text(
                          "← متابعة كزائر",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    bool isLtr = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
          decoration: InputDecoration(
            hintText: placeholder,
            hintTextDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A).withOpacity(0.7)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.grey.shade100,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }
}
