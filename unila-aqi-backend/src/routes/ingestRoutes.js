const express = require('express');
const router = express.Router();
const iotService = require('../services/iotService');

// POST /api/ingest/iot
// Dipanggil oleh device (simulator) setiap blok 30 detik.
router.post('/iot', async (req, res) => {
  if (!iotService.verifySecret(req.header('X-Ingest-Secret'))) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized device',
    });
  }

  try {
    const { status, ...body } = await iotService.ingestPush(req.body || {});
    return res.status(status).json(body);
  } catch (error) {
    console.error('❌ Ingest error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Ingest failed',
    });
  }
});

module.exports = router;