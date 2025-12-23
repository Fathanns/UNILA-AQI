import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/validators.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _codeControllers =
      List.generate(6, (index) => TextEditingController());
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<FocusNode> _codeFocusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _countdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Set up focus nodes to move to next field
    for (int i = 0; i < 5; i++) {
      _codeFocusNodes[i].addListener(() {
        if (!_codeFocusNodes[i].hasFocus && _codeControllers[i].text.length == 1) {
          FocusScope.of(context).requestFocus(_codeFocusNodes[i + 1]);
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var focusNode in _codeFocusNodes) {
      focusNode.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
            _startCountdown();
          } else {
            _canResend = true;
          }
        });
      }
    });
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    // Combine code from 6 fields
    String code = '';
    for (var controller in _codeControllers) {
      code += controller.text;
    }

    if (code.length != 6) {
      Helpers.showSnackBar(context, 'Masukkan 6 digit kode dengan lengkap', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Simulasi delay network
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      // Tampilkan dialog sukses
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Berhasil'),
          ],
        ),
        content: const Text(
          'Password telah berhasil direset! Anda dapat login menggunakan password baru Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              Navigator.pop(context); // Kembali ke login
            },
            child: const Text('LOGIN SEKARANG'),
          ),
        ],
      ),
    );
  }

  void _resendCode() {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _countdown = 60;
    });

    Helpers.showSnackBar(context, 'Kode verifikasi telah dikirim ulang');
    _startCountdown();
  }

  String _maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final username = parts[0];
    final domain = parts[1];
    if (username.length <= 3) return email;
    final masked = username.substring(0, 3) + '*' * (username.length - 3);
    return '$masked@$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('UNILA Air Quality Index'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.password,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'RESET PASSWORD',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 16),
              // Instruction
              const Text(
                'Kode verifikasi telah dikirim ke email:',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _maskedEmail(widget.email),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Verification Code
                    const Text(
                      'Masukkan 6 digit kode verifikasi:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 50,
                          child: TextFormField(
                            controller: _codeControllers[index],
                            focusNode: _codeFocusNodes[index],
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            onChanged: (value) {
                              if (value.length == 1 && index < 5) {
                                FocusScope.of(context).requestFocus(_codeFocusNodes[index + 1]);
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '';
                              }
                              return null;
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    // New Password
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Password Baru*',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscureNewPassword = !_obscureNewPassword);
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscureNewPassword,
                      validator: Validators.validatePassword,
                    ),
                    const SizedBox(height: 16),
                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi Password Baru*',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (value) => Validators.validateConfirmPassword(
                        value, _newPasswordController.text,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Reset Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'RESET PASSWORD',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Resend Code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _canResend ? _resendCode : null,
                    child: Text(
                      _canResend ? 'Kirim ulang kode' : 'Kirim ulang kode (${_countdown}s)',
                      style: TextStyle(
                        color: _canResend ? AppColors.primary : AppColors.textDisabled,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Password Requirements
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ketentuan Password:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Minimal 8 karakter\n• Kombinasi huruf dan angka\n• Hindari penggunaan password yang mudah ditebak',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Support Contact
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jika mengalami masalah, hubungi:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'admin@unila-aqi.ac.id\n(0721) 123-4567',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}