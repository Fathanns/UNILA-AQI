const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());              // agar bisa diakses dari domain lain
app.use(express.json());

// Endpoint utama: GET /api/air-quality
app.get('/api/air-quality', (req, res) => {
  try {
    const filePath = path.join(__dirname, 'data.json');
    const raw = fs.readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(raw);
    res.status(200).json(jsonData);
  } catch (err) {
    res.status(500).json({
      success: false,
      message: 'Gagal membaca data',
      error: err.message
    });
  }
});

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'OK', endpoint: '/api/air-quality' });
});

app.listen(PORT, () => {
  console.log(`Server berjalan di port ${PORT}`);
});