/**
 * ============================================================================
 * UNIT TEST — src/utils/aqiCalculator.js
 * ============================================================================
 *
 * Menguji 4 fungsi publik dari aqiCalculator.js:
 *   1. calculateISPUFromPM25(conc)       → ISPU 0-500 (dari PM2.5)
 *   2. calculateISPUFromPM10(conc)       → ISPU 0-500 (dari PM10)
 *   3. calculateAQI(pm25, pm10, co)      → { aqi, dominant, ispuPM25, ... }
 *   4. getAQICategory(aqi)               → { category, label, color }
 *
 * Standar acuan: PP No. 22 Tahun 2021 (Indonesia).
 *
 * ----------------------------------------------------------------------------
 * RUMUS INTERPOLASI LINEAR
 * ----------------------------------------------------------------------------
 *   ISPU = ((ISPU_high − ISPU_low) / (C_high − C_low)) × (C − C_low) + ISPU_low
 *
 * ----------------------------------------------------------------------------
 * KATEGORI ISPU (PP 22/2021)
 * ----------------------------------------------------------------------------
 *   0   –  50   : Baik
 *   51  – 100   : Sedang
 *   101 – 200   : Tidak Sehat
 *   201 – 300   : Sangat Tidak Sehat
 *   301 – 500   : Berbahaya
 *
 * ----------------------------------------------------------------------------
 * POLA PENGUJIAN TIAP FUNGSI
 * ----------------------------------------------------------------------------
 *   A. NILAI DI TENGAH SEGMEN  → verifikasi rumus interpolasi benar
 *   B. NILAI TEPAT DI BOUNDARY → pastikan tidak "bocor" ke segmen sebelah
 *   C. PERPINDAHAN SEGMEN      → pastikan titik "naik kelas" benar (+1 unit)
 *   D. NILAI EKSTREM / INVALID → pastikan clamp & sanitasi input bekerja
 *
 * ----------------------------------------------------------------------------
 * STRUKTUR FILE
 * ----------------------------------------------------------------------------
 *   BAGIAN 1 — calculateISPUFromPM25
 *   BAGIAN 2 — calculateISPUFromPM10
 *   BAGIAN 3 — calculateAQI  (MAX dari ketiga parameter)
 *   BAGIAN 4 — getAQICategory (batas antar kategori)
 * ============================================================================
 */

const { test, describe } = require('node:test');
const assert = require('node:assert');

const {
  calculateISPUFromPM25,
  calculateISPUFromPM10,
  calculateAQI,
  getAQICategory,
} = require('../aqiCalculator');


// ============================================================================
// BAGIAN 1 — calculateISPUFromPM25
// ============================================================================
// Tabel breakpoint PM2.5 (µg/m³) → ISPU:
//
//   ISPU          Konsentrasi (µg/m³)
//   ─────         ───────────────────
//     0 –  50        0 –  55
//    51 – 100       56 – 150
//   101 – 200      151 – 250
//   201 – 300      251 – 350
//   301 – 500      351 – 500
// ============================================================================
describe('calculateISPUFromPM25 — konversi PM2.5 (µg/m³) → ISPU', () => {

  // ── A. Nilai di tengah segmen (verifikasi rumus interpolasi) ─────────────

  test('PM2.5 = 0 → ISPU 0 (titik awal, tanpa interpolasi)', () => {
    assert.strictEqual(calculateISPUFromPM25(0), 0);
  });

  test('PM2.5 = 27.5 → ISPU 25 (tengah segmen 0–55)', () => {
    // (50 − 0)/(55 − 0) × (27.5 − 0) + 0 = 25
    assert.strictEqual(calculateISPUFromPM25(27.5), 25);
  });

  test('PM2.5 = 100 → ISPU 74 (tengah segmen 56–150)', () => {
    // (100 − 51)/(150 − 56) × (100 − 56) + 51
    //   = (49/94) × 44 + 51
    //   = 22.94 + 51
    //   ≈ 73.93  → dibulatkan 74
    assert.strictEqual(calculateISPUFromPM25(100), 74);
  });

  // ── B. Nilai tepat di boundary (tidak boleh "bocor" ke segmen sebelah) ──

  test('PM2.5 = 55 → ISPU 50 (batas atas segmen Baik, BUKAN 51)', () => {
    assert.strictEqual(calculateISPUFromPM25(55), 50);
  });

  test('PM2.5 = 150 → ISPU 100 (batas atas segmen Sedang)', () => {
    assert.strictEqual(calculateISPUFromPM25(150), 100);
  });

  test('PM2.5 = 250 → ISPU 200 (batas atas segmen Tidak Sehat)', () => {
    assert.strictEqual(calculateISPUFromPM25(250), 200);
  });

  // ── C. Perpindahan segmen (1 unit di atas boundary) ──────────────────────

  test('PM2.5 = 56 → ISPU 51 (naik 1 tingkat ke segmen Sedang)', () => {
    assert.strictEqual(calculateISPUFromPM25(56), 51);
  });

  test('PM2.5 = 151 → ISPU 101 (naik 1 tingkat ke segmen Tidak Sehat)', () => {
    assert.strictEqual(calculateISPUFromPM25(151), 101);
  });

  // ── D. Nilai ekstrem & input tidak valid (clamp + sanitasi) ──────────────

  test('PM2.5 = −5 (negatif) → ISPU 0 (di-clamp ke batas bawah)', () => {
    assert.strictEqual(calculateISPUFromPM25(-5), 0);
  });

  test('PM2.5 = 1000 (di atas 500) → ISPU 500 (di-clamp ke batas atas)', () => {
    assert.strictEqual(calculateISPUFromPM25(1000), 500);
  });

  test('PM2.5 = NaN → ISPU 0 (input tidak valid disanitasi)', () => {
    assert.strictEqual(calculateISPUFromPM25(NaN), 0);
  });

  test('PM2.5 = null → ISPU 0 (input null disanitasi)', () => {
    assert.strictEqual(calculateISPUFromPM25(null), 0);
  });
});


// ============================================================================
// BAGIAN 2 — calculateISPUFromPM10
// ============================================================================
// Tabel breakpoint PM10 (µg/m³) → ISPU:
//
//   ISPU          Konsentrasi (µg/m³)
//   ─────         ───────────────────
//     0 –  50        0 –  50
//    51 – 100       51 – 150
//   101 – 200      151 – 350
//   201 – 300      351 – 420
//   301 – 500      421 – 500
//
// CATATAN: seluruh test di bagian ini fokus pada BOUNDARY karena breakpoint
// PM10 bersinggungan tepat di integer (0/50/51/150/…). Rumus interpolasi
// sudah divalidasi lengkap di BAGIAN 1, jadi di sini cukup memastikan setiap
// batas segmen jatuh di ISPU yang benar.
// ============================================================================
describe('calculateISPUFromPM10 — konversi PM10 (µg/m³) → ISPU', () => {

  test('PM10 = 50 → ISPU 50 (batas atas segmen Baik)', () => {
    assert.strictEqual(calculateISPUFromPM10(50), 50);
  });

  test('PM10 = 51 → ISPU 51 (batas bawah segmen Sedang)', () => {
    assert.strictEqual(calculateISPUFromPM10(51), 51);
  });

  test('PM10 = 150 → ISPU 100 (batas atas segmen Sedang)', () => {
    assert.strictEqual(calculateISPUFromPM10(150), 100);
  });

  test('PM10 = 350 → ISPU 200 (batas atas segmen Tidak Sehat)', () => {
    assert.strictEqual(calculateISPUFromPM10(350), 200);
  });

  test('PM10 = 420 → ISPU 300 (batas atas segmen Sangat Tidak Sehat)', () => {
    assert.strictEqual(calculateISPUFromPM10(420), 300);
  });
});


// ============================================================================
// BAGIAN 3 — calculateAQI
// ============================================================================
// AQI = MAX(ISPU_PM25, ISPU_PM10, ISPU_CO).
//
// `dominant` = parameter penyumbang nilai MAX.
//
// ATURAN TIE (nilai ISPU sama di beberapa parameter):
//   Urutan pengecekan di implementasi adalah CO → PM2.5 → PM10.
//   Konsekuensi:
//     • CO tie dengan parameter lain   → CO menang
//     • PM2.5 tie dengan PM10          → PM2.5 menang
//
// Skenario yang diuji:
//   1. Masing-masing parameter menjadi dominan (PM10, PM2.5, CO)
//   2. Tie 2 arah & tie 3 arah
//   3. Konsistensi category/label mengikuti nilai MAX
// ============================================================================
describe('calculateAQI — AQI = MAX(ISPU PM2.5, ISPU PM10, ISPU CO)', () => {

  // ── Skenario 1: parameter dominan ────────────────────────────────────────

  test('PM10 dominan: PM2.5=20, PM10=60 → AQI 55, dominant "pm10"', () => {
    // PM2.5: (50/55) × 20                  = 18
    // PM10 : (49/99) × (60−51) + 51        = 55.45 → 55
    // CO   : 0                              = 0
    // MAX(18, 55, 0) = 55 → PM10 dominan
    const r = calculateAQI(20, 60);
    assert.strictEqual(r.aqi, 55);
    assert.strictEqual(r.dominant, 'pm10');
    assert.strictEqual(r.ispuPM25, 18);
    assert.strictEqual(r.ispuPM10, 55);
  });

  test('PM2.5 dominan: PM2.5=100, PM10=30 → AQI 74, dominant "pm25"', () => {
    // PM2.5: (49/94) × (100−56) + 51       = 73.93 → 74
    // PM10 : (50/50) × 30                  = 30
    // CO   : 0                              = 0
    // MAX(74, 30, 0) = 74 → PM2.5 dominan
    const r = calculateAQI(100, 30);
    assert.strictEqual(r.aqi, 74);
    assert.strictEqual(r.dominant, 'pm25');
  });

  test('CO dominan: PM2.5=10, PM10=20, CO=20000 → AQI 234, dominant "co"', () => {
    // PM2.5: (50/55) × 10                  ≈ 9
    // PM10 : (50/50) × 20                  = 20
    // CO   : segmen 15001–30000 µg/m³      → (99/14999) × (20000−15001) + 201 ≈ 234
    // MAX(9, 20, 234) = 234 → CO dominan
    const r = calculateAQI(10, 20, 20000);
    assert.strictEqual(r.aqi, 234);
    assert.strictEqual(r.dominant, 'co');
    assert.ok(r.ispuCO > r.ispuPM25);
    assert.ok(r.ispuCO > r.ispuPM10);
  });

  // ── Skenario 2: tie (nilai ISPU sama antar parameter) ────────────────────

  test('Tie PM2.5 vs PM10, CO rendah → dominant "pm25"', () => {
    // PM2.5 = 30 → ISPU (50/55) × 30 ≈ 27
    // PM10  = 27 → ISPU (50/50) × 27 = 27
    // CO    =  0 → ISPU = 0 (tidak ikut tie)
    // Tie PM2.5 vs PM10 → PM2.5 menang (dicek lebih dulu)
    const r = calculateAQI(30, 27, 0);
    assert.strictEqual(r.ispuPM25, r.ispuPM10);
    assert.ok(r.ispuPM25 > r.ispuCO);
    assert.strictEqual(r.dominant, 'pm25');
  });

  test('Tie 3 arah (semua ISPU = 0) → dominant "co"', () => {
    // PM2.5 = 0, PM10 = 0, CO = 0 → semua ISPU = 0
    // Tie 3 arah → CO menang (dicek lebih dulu)
    const r = calculateAQI(0, 0, 0);
    assert.strictEqual(r.aqi, 0);
    assert.strictEqual(r.ispuPM25, 0);
    assert.strictEqual(r.ispuPM10, 0);
    assert.strictEqual(r.ispuCO, 0);
    assert.strictEqual(r.dominant, 'co');
  });

  // ── Skenario 3: konsistensi category & label ─────────────────────────────

  test('Kategori mengikuti nilai MAX: AQI 55 → category "sedang", label "Sedang"', () => {
    const r = calculateAQI(20, 60);
    assert.strictEqual(r.category, 'sedang');
    assert.strictEqual(r.label, 'Sedang');
  });

  test('Semua input nol → AQI 0, category "baik"', () => {
    const r = calculateAQI(0, 0);
    assert.strictEqual(r.aqi, 0);
    assert.strictEqual(r.category, 'baik');
  });

  test('Input sangat tinggi (600, 600) → AQI 500 (clamped), category "berbahaya"', () => {
    const r = calculateAQI(600, 600);
    assert.strictEqual(r.aqi, 500);
    assert.strictEqual(r.category, 'berbahaya');
  });
});


// ============================================================================
// BAGIAN 4 — getAQICategory
// ============================================================================
// Memastikan nilai AQI jatuh ke kategori yang benar tepat di batas:
//
//   Batas 50/51   : Baik             ↔ Sedang
//   Batas 100/101 : Sedang           ↔ Tidak Sehat
//   Batas 200/201 : Tidak Sehat      ↔ Sangat Tidak Sehat
//   Batas 300/301 : Sangat Tidak Sehat ↔ Berbahaya
//
// Pola pengujian: setiap transisi diuji dengan SEPASANG test — nilai tepat
// di batas atas kategori lama (n), dan n+1 untuk memastikan "naik kelas".
// ============================================================================
describe('getAQICategory — batas kategori sesuai PP 22/2021', () => {

  // ── Baik ↔ Sedang (batas 50/51) ──────────────────────────────────────────

  test('AQI = 50 → category "baik" (batas atas)', () => {
    assert.strictEqual(getAQICategory(50).category, 'baik');
  });

  test('AQI = 51 → category "sedang" (batas bawah)', () => {
    assert.strictEqual(getAQICategory(51).category, 'sedang');
  });

  // ── Sedang ↔ Tidak Sehat (batas 100/101) ─────────────────────────────────

  test('AQI = 100 → category "sedang" (batas atas)', () => {
    assert.strictEqual(getAQICategory(100).category, 'sedang');
  });

  test('AQI = 101 → category "tidak_sehat" (batas bawah)', () => {
    assert.strictEqual(getAQICategory(101).category, 'tidak_sehat');
  });

  // ── Tidak Sehat ↔ Sangat Tidak Sehat (batas 200/201) ─────────────────────

  test('AQI = 200 → category "tidak_sehat" (batas atas)', () => {
    assert.strictEqual(getAQICategory(200).category, 'tidak_sehat');
  });

  test('AQI = 201 → category "sangat_tidak_sehat" (batas bawah)', () => {
    assert.strictEqual(getAQICategory(201).category, 'sangat_tidak_sehat');
  });

  // ── Sangat Tidak Sehat ↔ Berbahaya (batas 300/301) ───────────────────────

  test('AQI = 300 → category "sangat_tidak_sehat" (batas atas)', () => {
    assert.strictEqual(getAQICategory(300).category, 'sangat_tidak_sehat');
  });

  test('AQI = 301 → category "berbahaya" (batas bawah)', () => {
    assert.strictEqual(getAQICategory(301).category, 'berbahaya');
  });

  // ── Batas atas global (500) ──────────────────────────────────────────────

  test('AQI = 500 → category "berbahaya" (batas atas skala)', () => {
    assert.strictEqual(getAQICategory(500).category, 'berbahaya');
  });
});