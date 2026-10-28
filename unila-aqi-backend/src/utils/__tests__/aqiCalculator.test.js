const { test, describe } = require('node:test');
const assert = require('node:assert');

const {
  calculateISPUFromPM25,
  calculateISPUFromPM10,
  calculateAQI,
  getAQICategory,
} = require('../aqiCalculator');


describe('calculateISPUFromPM25', () => {

  // === Kategori A: Nilai di tengah segmen ===
  test('PM2.5 = 0 → ISPU 0', () => {
    assert.strictEqual(calculateISPUFromPM25(0), 0);
  });

  test('PM2.5 = 27.5 (tengah segmen 0-55) → ISPU 25', () => {
    // (50/55) × 27.5 = 25
    assert.strictEqual(calculateISPUFromPM25(27.5), 25);
  });

  test('PM2.5 = 100 (tengah segmen 56-150) → ISPU ~74', () => {
    // (49/94) × (100-56) + 51 = 22.93 + 51 = 73.93 → round 74
    assert.strictEqual(calculateISPUFromPM25(100), 74);
  });

  // === Kategori B: Boundary exact ===
  test('PM2.5 = 55 → ISPU tepat 50 (bukan 51)', () => {
    assert.strictEqual(calculateISPUFromPM25(55), 50);
  });

  test('PM2.5 = 150 → ISPU tepat 100', () => {
    assert.strictEqual(calculateISPUFromPM25(150), 100);
  });

  test('PM2.5 = 250 → ISPU tepat 200', () => {
    assert.strictEqual(calculateISPUFromPM25(250), 200);
  });

  // === Kategori C: Perpindahan segmen ===
  test('PM2.5 = 56 → ISPU tepat 51 (naik ke segmen Sedang)', () => {
    assert.strictEqual(calculateISPUFromPM25(56), 51);
  });

  test('PM2.5 = 151 → ISPU tepat 101', () => {
    assert.strictEqual(calculateISPUFromPM25(151), 101);
  });

  // === Kategori D: Nilai ekstrem ===
  test('PM2.5 negatif → ISPU 0 (clamp)', () => {
    assert.strictEqual(calculateISPUFromPM25(-5), 0);
  });

  test('PM2.5 di atas 500 → ISPU 500 (clamp)', () => {
    assert.strictEqual(calculateISPUFromPM25(1000), 500);
  });

  test('PM2.5 = NaN → ISPU 0', () => {
    assert.strictEqual(calculateISPUFromPM25(NaN), 0);
  });

  test('PM2.5 = null → ISPU 0', () => {
    assert.strictEqual(calculateISPUFromPM25(null), 0);
  });
});


describe('calculateISPUFromPM10', () => {

  test('PM10 = 50 → ISPU tepat 50', () => {
    assert.strictEqual(calculateISPUFromPM10(50), 50);
  });

  test('PM10 = 51 → ISPU tepat 51', () => {
    assert.strictEqual(calculateISPUFromPM10(51), 51);
  });

  test('PM10 = 150 → ISPU tepat 100', () => {
    assert.strictEqual(calculateISPUFromPM10(150), 100);
  });

  test('PM10 = 350 → ISPU tepat 200', () => {
    assert.strictEqual(calculateISPUFromPM10(350), 200);
  });

  test('PM10 = 420 → ISPU tepat 300', () => {
    assert.strictEqual(calculateISPUFromPM10(420), 300);
  });
});


describe('calculateAQI (MAX of PM2.5 & PM10)', () => {

  test('PM10 dominan (PM2.5 kecil)', () => {
    const r = calculateAQI(20, 60);
    // PM2.5: (50/55)×20 = 18; PM10: (49/99)×(60-51)+51 = 55.45 → 55
    // MAX(18, 55) = 55, dominant pm10
    assert.strictEqual(r.aqi, 55);
    assert.strictEqual(r.dominant, 'pm10');
    assert.strictEqual(r.ispuPM25, 18);
    assert.strictEqual(r.ispuPM10, 55);
  });

  test('PM2.5 dominan', () => {
    const r = calculateAQI(100, 30);
    // PM2.5: (49/94)×(100-56)+51 = 73.93 → 74; PM10: (50/50)×30 = 30
    // MAX(74, 30) = 74, dominant pm25
    assert.strictEqual(r.aqi, 74);
    assert.strictEqual(r.dominant, 'pm25');
  });

  test('Tie → dominant pm25 (default)', () => {
    const r = calculateAQI(50, 50);
    // PM2.5: (50/55)×50 = 45; PM10: (50/50)×50 = 50
    // Tidak tie. Coba lain:
    const r2 = calculateAQI(0, 0);
    assert.strictEqual(r2.aqi, 0);
    assert.strictEqual(r2.dominant, 'pm25'); // tie → PM2.5 dipilih
  });

  test('Kategori ikut hasil MAX', () => {
    const r = calculateAQI(20, 60);
    assert.strictEqual(r.category, 'sedang'); // AQI 55 masuk 51-100
    assert.strictEqual(r.label, 'Sedang');
  });

  test('Kedua nilai 0 → AQI 0, kategori baik', () => {
    const r = calculateAQI(0, 0);
    assert.strictEqual(r.aqi, 0);
    assert.strictEqual(r.category, 'baik');
  });

  test('Kedua nilai sangat tinggi → AQI 500', () => {
    const r = calculateAQI(600, 600);
    assert.strictEqual(r.aqi, 500);
    assert.strictEqual(r.category, 'berbahaya');
  });
});


describe('getAQICategory (batas PP 22/2021)', () => {

  test('50 → baik (batas atas baik)', () => {
    assert.strictEqual(getAQICategory(50).category, 'baik');
  });

  test('51 → sedang (batas bawah sedang)', () => {
    assert.strictEqual(getAQICategory(51).category, 'sedang');
  });

  test('100 → sedang', () => {
    assert.strictEqual(getAQICategory(100).category, 'sedang');
  });

  test('101 → tidak_sehat', () => {
    assert.strictEqual(getAQICategory(101).category, 'tidak_sehat');
  });

  test('200 → tidak_sehat (batas atas)', () => {
    assert.strictEqual(getAQICategory(200).category, 'tidak_sehat');
  });

  test('201 → sangat_tidak_sehat', () => {
    assert.strictEqual(getAQICategory(201).category, 'sangat_tidak_sehat');
  });

  test('300 → sangat_tidak_sehat (batas atas)', () => {
    assert.strictEqual(getAQICategory(300).category, 'sangat_tidak_sehat');
  });

  test('301 → berbahaya', () => {
    assert.strictEqual(getAQICategory(301).category, 'berbahaya');
  });

  test('500 → berbahaya', () => {
    assert.strictEqual(getAQICategory(500).category, 'berbahaya');
  });
});