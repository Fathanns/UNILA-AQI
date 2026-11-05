const axios = require('axios');

// ============================================================
// 1) KONFIGURASI EMAIL (MENGGUNAKAN HTTP API, BUKAN SMTP)
// ============================================================
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const EMAIL_USER = process.env.EMAIL_USER; // Tetap gunakan env ini sebagai alamat pengirim

if (!RESEND_API_KEY) {
  console.error('❌ FATAL: RESEND_API_KEY wajib di-set di Render Environment Variables.');
  process.exit(1);
}

const generateResetCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const sendEmailViaResend = async (toEmail, subject, htmlContent) => {
  try {
    const response = await axios.post(
      'https://api.resend.com/emails',
      {
        from: 'Unila AQI <onboarding@resend.dev>', // Resend free tier wajib pakai domain ini untuk testing
        to: [toEmail],
        subject: subject,
        html: htmlContent,
      },
      {
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );
    return response.data;
  } catch (error) {
    console.error('❌ Resend API Error:', error.response?.data || error.message);
    throw error;
  }
};

const sendResetCodeEmail = async (toEmail, code, username) => {
  const htmlContent = `
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
  `;
  return await sendEmailViaResend(toEmail, 'Kode Reset Password - Unila AQI', htmlContent);
};

const sendEmailChangeCodeEmail = async (toEmail, code, username) => {
  const htmlContent = `
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
  `;
  return await sendEmailViaResend(toEmail, 'Kode Verifikasi Perubahan Email - Unila AQI', htmlContent);
};

module.exports = {
  generateResetCode,
  sendResetCodeEmail,
  sendEmailChangeCodeEmail,
};