const nodemailer = require('nodemailer');

const EMAIL_USER = process.env.EMAIL_USER;
const EMAIL_PASS = process.env.EMAIL_PASS;

if (!EMAIL_USER || !EMAIL_PASS) {
  console.error('❌ FATAL: EMAIL_USER dan EMAIL_PASS wajib di-set.');
  console.error('   Lokal  : tambahkan ke file .env lalu restart server.');
  console.error('   Render : tambahkan ke Environment Variables di dashboard Render.');
  console.error('   Nilai  : EMAIL_PASS harus berupa Gmail App Password (16 karakter),');
  console.error('            bukan password login Gmail biasa.');
  process.exit(1);
}

// Masking untuk log startup (jangan pernah log password)
const maskedUser = (() => {
  const parts = EMAIL_USER.split('@');
  if (parts.length !== 2) return '***';
  const [name, domain] = parts;
  const visible = name.slice(0, Math.min(3, name.length));
  return `${visible}***@${domain}`;
})();

console.log(`📧 Email service configured for: ${maskedUser}`);


const transporter = nodemailer.createTransport({
  service: 'gmail',
  secure: true,
  auth: {
    user: EMAIL_USER,
    pass: EMAIL_PASS,
  },
  // Timeout agar tidak menggantung jika Gmail tidak merespons
  connectionTimeout: 10000, // 10 detik
  greetingTimeout: 10000,
  socketTimeout: 15000,
});

// Verifikasi koneksi saat startup (non-blocking, hanya log)
transporter.verify((error) => {
  if (error) {
    console.error('⚠️  Email transporter verification failed:', error.message);
    console.error('   Cek kembali EMAIL_USER / EMAIL_PASS di environment variables.');
    console.error('   Jika EMAIL_PASS adalah password login biasa, ubah ke Gmail App Password.');
  } else {
    console.log('✅ Email transporter ready (Gmail SMTP)');
  }
});

// ============================================================
// 3) GENERATOR KODE 6-DIGIT
// ============================================================
const generateResetCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// ============================================================
// 4) TEMPLATE EMAIL — RESET PASSWORD
// ============================================================
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
            © ${new Date().getFullYear()} Unila Air Quality Index
          </p>
        </div>
      </div>
    `,
  };

  return await transporter.sendMail(mailOptions);
};

const sendEmailChangeCodeEmail = async (toEmail, code, username) => {
  const mailOptions = {
    from: `"Unila AQI" <${EMAIL_USER}>`,
    to: toEmail,
    subject: 'Kode Verifikasi Perubahan Email - Unila AQI',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #0066CC, #3388FF); padding: 24px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0;">Unila AQI</h1>
          <p style="color: #e3f2fd; margin: 8px 0 0 0;">Verifikasi Perubahan Email</p>
        </div>
        <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e9ecef;">
          <h2 style="color: #212529; margin-top: 0;">Kode Verifikasi</h2>
          <p style="color: #495057; font-size: 16px;">Halo <strong>${username}</strong>,</p>
          <p style="color: #495057; font-size: 16px;">
            Kami menerima permintaan untuk mengubah email akun admin Anda.
            Gunakan kode verifikasi berikut:
          </p>
          <div style="background: #0066CC; color: white; font-size: 36px; font-weight: bold; text-align: center; padding: 24px; border-radius: 10px; letter-spacing: 10px; margin: 24px 0;">
            ${code}
          </div>
          <p style="color: #6C757D; font-size: 14px;">
            Kode ini berlaku selama <strong>15 menit</strong>.
            Jika Anda tidak meminta perubahan email, abaikan email ini.
          </p>
          <hr style="border: none; border-top: 1px solid #dee2e6; margin: 24px 0;">
          <p style="color: #adb5bd; font-size: 12px; text-align: center; margin: 0;">
            © ${new Date().getFullYear()} Unila Air Quality Index
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
  sendEmailChangeCodeEmail,
};