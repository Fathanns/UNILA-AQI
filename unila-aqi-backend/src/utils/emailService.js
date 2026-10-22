const nodemailer = require('nodemailer');

// Konfigurasi email (dari user)
const EMAIL_USER = process.env.EMAIL_USER || 'mayangsarigizi@gmail.com';
const EMAIL_PASS = process.env.EMAIL_PASS || 'coie fjza nkdr kvug';

// Buat transporter Gmail
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: EMAIL_USER,
    pass: EMAIL_PASS,
  },
});

/**
 * Generate 6-digit code
 */
const generateResetCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Kirim email berisi kode verifikasi
 */
const sendResetCodeEmail = async (toEmail, code, username) => {
  const mailOptions = {
    from: `"Unila AQI" <${EMAIL_USER}>`,
    to: toEmail,
    subject: 'Kode Reset Password - Unila AQI',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #0066CC, #3388FF); padding: 24px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0;">Unila AQI</h1>
          <p style="color: #e3f2fd; margin: 8px 0 0 0;">Air Quality Index Monitoring System</p>
        </div>
        <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e9ecef;">
          <h2 style="color: #212529; margin-top: 0;">Reset Password</h2>
          <p style="color: #495057; font-size: 16px;">Halo <strong>${username}</strong>,</p>
          <p style="color: #495057; font-size: 16px;">
            Kami menerima permintaan untuk reset password akun admin Anda.
            Gunakan kode verifikasi berikut:
          </p>
          <div style="background: #0066CC; color: white; font-size: 36px; font-weight: bold; text-align: center; padding: 24px; border-radius: 10px; letter-spacing: 10px; margin: 24px 0;">
            ${code}
          </div>
          <p style="color: #6C757D; font-size: 14px;">
            Kode ini berlaku selama <strong>15 menit</strong>. 
            Jika Anda tidak meminta reset password, abaikan email ini.
          </p>
          <hr style="border: none; border-top: 1px solid #dee2e6; margin: 24px 0;">
          <p style="color: #adb5bd; font-size: 12px; text-align: center; margin: 0;">
            © 2025 Unila Air Quality Index
          </p>
        </div>
      </div>
    `,
  };

  return await transporter.sendMail(mailOptions);
};

module.exports = {
  generateResetCode,
  sendResetCodeEmail,
};