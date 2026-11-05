const nodemailer = require('nodemailer');

// ============================================================
// 1) KONFIGURASI EMAIL (SMTP CUSTOM)
// ============================================================
const SMTP_HOST = process.env.SMTP_HOST || 'smtp.emailsbit.com';
const SMTP_PORT = parseInt(process.env.SMTP_PORT || '588', 10);
const SMTP_USER = process.env.SMTP_USERNAME;
const SMTP_PASS = process.env.SMTP_PASSWORD;
const SMTP_FROM = process.env.SMTP_FROM || 'unilaaqi@inboxtaken.com';

if (!SMTP_USER || !SMTP_PASS) {
  console.error('❌ FATAL: SMTP_USERNAME dan SMTP_PASSWORD wajib di-set di Render Environment Variables.');
  process.exit(1);
}

const transporter = nodemailer.createTransport({
  host: SMTP_HOST,
  port: SMTP_PORT,
  secure: false,       // Wajib false untuk STARTTLS (port 588)
  requireTLS: true,    // Memaksa koneksi dienkripsi via STARTTLS
  auth: {
    user: SMTP_USER,
    pass: SMTP_PASS,
  },
  connectionTimeout: 15000, // Toleransi 15 detik
});

// Verifikasi koneksi saat startup (non-blocking)
transporter.verify((error) => {
  if (error) {
    console.error('⚠️  SMTP transporter verification failed:', error.message);
  } else {
    console.log('✅ SMTP transporter ready (EmailSbit/Sendcorex)');
  }
});

const generateResetCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const sendResetCodeEmail = async (toEmail, code, username) => {
  const mailOptions = {
    from: `"Unila AQI" <${SMTP_FROM}>`, // Harus menggunakan domain dari SMTP_FROM
    to: toEmail,
    subject: 'Kode Reset Password - Unila AQI',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #0066CC, #3388FF); padding: 24px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0;">Unila AQI</h1>
        </div>
        <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e9ecef;">
          <h2 style="color: #212529; margin-top: 0;">Reset Password</h2>
          <p style="color: #495057; font-size: 16px;">Halo <strong>${username}</strong>,</p>
          <p style="color: #495057; font-size: 16px;">Kode verifikasi reset password Anda:</p>
          <div style="background: #0066CC; color: white; font-size: 36px; font-weight: bold; text-align: center; padding: 24px; border-radius: 10px; letter-spacing: 10px; margin: 24px 0;">
            ${code}
          </div>
          <p style="color: #6C757D; font-size: 14px;">Kode ini berlaku selama <strong>15 menit</strong>.</p>
        </div>
      </div>
    `,
  };

  return await transporter.sendMail(mailOptions);
};

const sendEmailChangeCodeEmail = async (toEmail, code, username) => {
  const mailOptions = {
    from: `"Unila AQI" <${SMTP_FROM}>`,
    to: toEmail,
    subject: 'Kode Verifikasi Perubahan Email - Unila AQI',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #0066CC, #3388FF); padding: 24px; border-radius: 10px 10px 0 0; text-align: center;">
          <h1 style="color: white; margin: 0;">Unila AQI</h1>
        </div>
        <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e9ecef;">
          <h2 style="color: #212529; margin-top: 0;">Verifikasi Perubahan Email</h2>
          <p style="color: #495057; font-size: 16px;">Halo <strong>${username}</strong>,</p>
          <p style="color: #495057; font-size: 16px;">Kode verifikasi perubahan email Anda:</p>
          <div style="background: #0066CC; color: white; font-size: 36px; font-weight: bold; text-align: center; padding: 24px; border-radius: 10px; letter-spacing: 10px; margin: 24px 0;">
            ${code}
          </div>
          <p style="color: #6C757D; font-size: 14px;">Kode ini berlaku selama <strong>15 menit</strong>.</p>
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