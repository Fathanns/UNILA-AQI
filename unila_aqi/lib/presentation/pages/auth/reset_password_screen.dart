import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/services/api_service.dart';
import 'admin_login_screen.dart';
import 'package:flutter/services.dart';


class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();   // ✅ ganti 6 controller
  final _codeFocusNode = FocusNode();    
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _countdown = 60;
  bool _canResend = false;

  @override
void initState() {
  super.initState();
  _codeController.addListener(() => setState(() {})); // update kotak visual
  _startCountdown();
}

  @override
void dispose() {
  _codeController.dispose();
  _codeFocusNode.dispose();
  _newPasswordController.dispose();
  _confirmPasswordController.dispose();
  super.dispose();
}

  // ============================================================
  // COUNTDOWN UNTUK KIRIM ULANG KODE
  // ============================================================
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

  // ============================================================
  // RESET PASSWORD (VALIDASI KODE + SIMPAN PASSWORD BARU)
  // ============================================================
   Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text;
    if (code.length != 6) {
      Helpers.showSnackBar(
        context,
        'Masukkan 6 digit kode dengan lengkap',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService().resetPasswordWithCode(
        email: widget.email,
        code: code,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() => _isLoading = false);
        _showSuccessDialog();
      } else {
        setState(() => _isLoading = false);
        Helpers.showSnackBar(
          context,
          response['message'] ?? 'Gagal mereset password',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Server mati -> SnackBar khusus, tidak reset password
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
        return;
      }

      final rawMsg = e.toString().replaceFirst('Exception: ', '');
      String message = rawMsg;
      if (rawMsg.toLowerCase().contains('kode') &&
          rawMsg.toLowerCase().contains('salah')) {
        message =
            'Kode verifikasi salah. Periksa kembali kode yang Anda masukkan.';
      } else if (rawMsg.toLowerCase().contains('kedaluwarsa') ||
          rawMsg.toLowerCase().contains('expired')) {
        message = 'Kode sudah kedaluwarsa. Silakan kirim ulang kode.';
      }

      Helpers.showSnackBar(context, message, isError: true);
    }
  }

  // ============================================================
  // KIRIM ULANG KODE (RESEND)
  // ============================================================
  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService().resendResetCode(widget.email);

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _isLoading = false;
          _canResend = false;
          _countdown = 60;
        });

        Helpers.showSnackBar(
          context,
          'Kode verifikasi baru telah dikirim ke email Anda',
        );

        _startCountdown();
      } else {
        setState(() => _isLoading = false);
        Helpers.showSnackBar(
          context,
          response['message'] ?? 'Gagal mengirim ulang kode',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
        return;
      }

      final rawMsg = e.toString().replaceFirst('Exception: ', '');
      Helpers.showSnackBar(
        context,
        'Gagal mengirim ulang kode: $rawMsg',
        isError: true,
      );
    }
  }

  // ============================================================
  // DIALOG SUKSES
  // ============================================================
  void _showSuccessDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Berhasil'),
      content: const Text(
        'Password telah berhasil direset. '
        'Silakan login kembali menggunakan password baru Anda.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext); // Tutup dialog

            // 🔥 Kembali ke halaman login admin, bersihkan stack
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminLoginScreen(),
              ),
              (route) => false,
            );
          },
          child: const Text('LOGIN SEKARANG'),
        ),
      ],
    ),
  );
}

  // ============================================================
  // HELPER: MASKED EMAIL
  // ============================================================
  String _maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final username = parts[0];
    final domain = parts[1];
    if (username.length <= 3) return email;
    final masked = username.substring(0, 3) + '*' * (username.length - 3);
    return '$masked@$domain';
  }

  // ============================================================
  // UI BUILD
  // ============================================================
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
                decoration: const BoxDecoration(
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
                    GestureDetector(
  onTap: () => _codeFocusNode.requestFocus(),
  child: Stack(
    children: [
      // TextField asli, disembunyikan (opacity 0) tapi tetap menerima input
      Opacity(
        opacity: 0,
        child: TextField(
          controller: _codeController,
          focusNode: _codeFocusNode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly, // hanya angka
          ],
          decoration: const InputDecoration(counterText: ''),
        ),
      ),

      // Kotak visual 6 digit
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          final hasChar = _codeController.text.length > index;
          final isCursorHere =
              _codeFocusNode.hasFocus &&
              _codeController.text.length == index;
          final isFocused = isCursorHere;

          return Container(
            width: 50,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFocused
                    ? AppColors.primary
                    : AppColors.border,
                width: isFocused ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              hasChar ? _codeController.text[index] : '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),
      ),
    ],
  ),
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
                            setState(() =>
                                _obscureNewPassword = !_obscureNewPassword);
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
                            setState(() => _obscureConfirmPassword =
                                !_obscureConfirmPassword);
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (value) => Validators.validateConfirmPassword(
                        value,
                        _newPasswordController.text,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Reset Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        child: const Text(
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
                    onPressed: _canResend && !_isLoading ? _resendCode : null,
                    child: Text(
                      _canResend
                          ? 'Kirim ulang kode'
                          : 'Kirim ulang kode (${_countdown}s)',
                      style: TextStyle(
                        color: _canResend
                            ? AppColors.primary
                            : AppColors.textDisabled,
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
                      '• Minimal 8 karakter\n'
                      '• Kombinasi huruf dan angka\n'
                      '• Hindari penggunaan password yang mudah ditebak',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}