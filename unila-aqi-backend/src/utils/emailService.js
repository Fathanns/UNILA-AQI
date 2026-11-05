const axios = require('axios');

// ============================================================
// 1) KONFIGURASI EMAIL (SENDGRID API)
// ============================================================
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY;
const SENDER_EMAIL = process.env.EMAIL_USER || 'fathannursidiq01@gmail.com'; // Email yang diverifikasi di SendGrid

if (!SENDGRID_API_KEY) {
  console.error('❌ FATAL: SENDGRID_API_KEY wajib di-set di Render Environment Variables.');
  process.exit(1);
}

const generateResetCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const sendEmailViaSendGrid = async (toEmail, subject, htmlContent) => {
  try {
    const response = await axios.post(
      'https://api.sendgrid.com/v3/mail/send',
      {
        personalizations: [
          {
            to: [{ email: toEmail }],
            subject: subject,
          },
        ],
        from: {
          email: SENDER_EMAIL,
          name: 'Unila AQI',
        },
        content: [
          {
            type: 'text/html',
            value: htmlContent,
          },
        ],
      },
      {
        headers: {
          Authorization: `Bearer ${SENDGRID_API_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );
    return response.data;
  } catch (error) {
    console.error('❌ SendGrid API Error:', error.response?.data || error.message);
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
  return await sendEmailViaSendGrid(toEmail, 'Kode Reset Password - Unila AQI', htmlContent);
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
  return await sendEmailViaSendGrid(toEmail, 'Kode Verifikasi Perubahan Email - Unila AQI', htmlContent);
};

module.exports = {
  generateResetCode,
  sendResetCodeEmail,
  sendEmailChangeCodeEmail,
};