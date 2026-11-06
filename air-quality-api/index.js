const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;   // ← WAJIB pakai process.env.PORT

app.use(cors());
app.use(express.json());

// Endpoint utama
app.get('/api/air-quality', (req, res) => {
  try {
    const filePath = path.join(__dirname, 'data.json');
    const raw = fs.readFileSync(filePath, 'utf-8');
    res.status(200).json(JSON.parse(raw));
  } catch (err) {
    res.status(500).json({
      success: false,
      message: 'Gagal membaca data',
      error: err.message
    });
  }
});

// Health check (dipakai Render untuk cek server hidup)
app.get('/', (req, res) => {
  res.json({
    status: 'OK',
    endpoint: '/api/air-quality',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server berjalan di port ${PORT}`);
});