/**
 * ISPU Calculator — PP No. 22 Tahun 2021
 * AQI = MAX dari semua parameter yang TERSEDIA (non-null).
 * Jika semua null → aqi = null, category = 'no_data'.
 */

const PM25_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,   concHigh: 55  },
  { ispuLow: 51,  ispuHigh: 100, concLow: 56,  concHigh: 150 },
  { ispuLow: 101, ispuHigh: 200, concLow: 151, concHigh: 250 },
  { ispuLow: 201, ispuHigh: 300, concLow: 251, concHigh: 350 },
  { ispuLow: 301, ispuHigh: 500, concLow: 351, concHigh: 500 },
];
const PM10_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,   concHigh: 50  },
  { ispuLow: 51,  ispuHigh: 100, concLow: 51,  concHigh: 150 },
  { ispuLow: 101, ispuHigh: 200, concLow: 151, concHigh: 350 },
  { ispuLow: 201, ispuHigh: 300, concLow: 351, concHigh: 420 },
  { ispuLow: 301, ispuHigh: 500, concLow: 421, concHigh: 500 },
];
const CO_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,     concHigh: 4000  },
  { ispuLow: 51,  ispuHigh: 100, concLow: 4001,  concHigh: 8000  },
  { ispuLow: 101, ispuHigh: 200, concLow: 8001,  concHigh: 15000 },
  { ispuLow: 201, ispuHigh: 300, concLow: 15001, concHigh: 30000 },
  { ispuLow: 301, ispuHigh: 500, concLow: 30001, concHigh: 45000 },
];
const SO2_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,    concHigh: 80   },
  { ispuLow: 51,  ispuHigh: 100, concLow: 81,   concHigh: 365  },
  { ispuLow: 101, ispuHigh: 200, concLow: 366,  concHigh: 800  },
  { ispuLow: 201, ispuHigh: 300, concLow: 801,  concHigh: 1600 },
  { ispuLow: 301, ispuHigh: 500, concLow: 1601, concHigh: 3000 },
];
const O3_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,   concHigh: 120  },
  { ispuLow: 51,  ispuHigh: 100, concLow: 121, concHigh: 235  },
  { ispuLow: 101, ispuHigh: 200, concLow: 236, concHigh: 400  },
  { ispuLow: 201, ispuHigh: 300, concLow: 401, concHigh: 800  },
  { ispuLow: 301, ispuHigh: 500, concLow: 801, concHigh: 1000 },
];
const NO2_BREAKPOINTS = [
  { ispuLow: 0,   ispuHigh: 50,  concLow: 0,    concHigh: 80   },
  { ispuLow: 51,  ispuHigh: 100, concLow: 81,   concHigh: 200  },
  { ispuLow: 101, ispuHigh: 200, concLow: 201,  concHigh: 1130 },
  { ispuLow: 201, ispuHigh: 300, concLow: 1131, concHigh: 2260 },
  { ispuLow: 301, ispuHigh: 500, concLow: 2261, concHigh: 3000 },
];

const isValidNumber = (v) =>
  typeof v === 'number' && Number.isFinite(v) && !Number.isNaN(v);

function calculateISPUFromConcentration(concentration, breakpoints) {
  if (!isValidNumber(concentration) || concentration < 0) return null;

  for (const bp of breakpoints) {
    if (concentration <= bp.concHigh) {
      const concRange = bp.concHigh - bp.concLow;
      if (concRange === 0) return bp.ispuHigh;
      const ispu =
        ((bp.ispuHigh - bp.ispuLow) / concRange) *
          (concentration - bp.concLow) +
        bp.ispuLow;
      return Math.round(Math.max(0, Math.min(500, ispu)));
    }
  }
  return 500;
}

const calculateISPUFromPM25 = (v) => calculateISPUFromConcentration(v, PM25_BREAKPOINTS);
const calculateISPUFromPM10 = (v) => calculateISPUFromConcentration(v, PM10_BREAKPOINTS);
const calculateISPUFromCO   = (v) => calculateISPUFromConcentration(v, CO_BREAKPOINTS);
const calculateISPUFromSO2  = (v) => calculateISPUFromConcentration(v, SO2_BREAKPOINTS);
const calculateISPUFromO3   = (v) => calculateISPUFromConcentration(v, O3_BREAKPOINTS);
const calculateISPUFromNO2  = (v) => calculateISPUFromConcentration(v, NO2_BREAKPOINTS);

/**
 * AQI = MAX dari parameter yang tersedia.
 * Semua parameter nullable. Bila SEMUA null → aqi: null, category: 'no_data'.
 * Tie-breaker: CO → SO2 → O3 → NO2 → PM2.5 → PM10
 */
function calculateAQI(pm25 = null, pm10 = null, co = null, so2 = null, o3 = null, no2 = null) {
  const hasPM25 = isValidNumber(pm25);
  const hasPM10 = isValidNumber(pm10);
  const hasCO   = isValidNumber(co);
  const hasSO2  = isValidNumber(so2);
  const hasO3   = isValidNumber(o3);
  const hasNO2  = isValidNumber(no2);

  if (!hasPM25 && !hasPM10 && !hasCO && !hasSO2 && !hasO3 && !hasNO2) {
    const cat = getAQICategory(null);
    return {
      aqi: null,
      ispuPM25: null, ispuPM10: null, ispuCO: null,
      ispuSO2: null, ispuO3: null, ispuNO2: null,
      dominant: null,
      category: cat.category,
      color: cat.color,
      label: cat.label,
    };
  }

  const ispuPM25 = hasPM25 ? calculateISPUFromPM25(pm25) : null;
  const ispuPM10 = hasPM10 ? calculateISPUFromPM10(pm10) : null;
  const ispuCO   = hasCO   ? calculateISPUFromCO(co)     : null;
  const ispuSO2  = hasSO2  ? calculateISPUFromSO2(so2)   : null;
  const ispuO3   = hasO3   ? calculateISPUFromO3(o3)     : null;
  const ispuNO2  = hasNO2  ? calculateISPUFromNO2(no2)   : null;

  const ordered = [
    ...(hasCO   ? [{ name: 'co',   value: ispuCO   }] : []),
    ...(hasSO2  ? [{ name: 'so2',  value: ispuSO2  }] : []),
    ...(hasO3   ? [{ name: 'o3',   value: ispuO3   }] : []),
    ...(hasNO2  ? [{ name: 'no2',  value: ispuNO2  }] : []),
    ...(hasPM25 ? [{ name: 'pm25', value: ispuPM25 }] : []),
    ...(hasPM10 ? [{ name: 'pm10', value: ispuPM10 }] : []),
  ];

  const aqi = Math.max(...ordered.map((c) => c.value));
  const dominant = ordered.find((c) => c.value === aqi)?.name || null;

  const cat = getAQICategory(aqi);

  return {
    aqi,
    ispuPM25, ispuPM10, ispuCO, ispuSO2, ispuO3, ispuNO2,
    dominant,
    category: cat.category,
    color: cat.color,
    label: cat.label,
  };
}

function getAQICategory(aqi) {
  if (aqi == null || Number.isNaN(aqi)) {
    return { category: 'no_data', color: '#BDBDBD', label: 'Tidak Ada Data' };
  }
  if (aqi <= 50)  return { category: 'baik',               color: '#00E400', label: 'Baik' };
  if (aqi <= 100) return { category: 'sedang',             color: '#0000FF', label: 'Sedang' };
  if (aqi <= 200) return { category: 'tidak_sehat',        color: '#FFFF00', label: 'Tidak Sehat' };
  if (aqi <= 300) return { category: 'sangat_tidak_sehat', color: '#FF0000', label: 'Sangat Tidak Sehat' };
  return { category: 'berbahaya', color: '#000000', label: 'Berbahaya' };
}

function aqiToConcentration(aqi, breakpoints) {
  if (!isValidNumber(aqi) || aqi <= 0) return 0;
  const target = Math.min(500, aqi);
  for (const bp of breakpoints) {
    if (target <= bp.ispuHigh) {
      const ispuRange = bp.ispuHigh - bp.ispuLow;
      if (ispuRange === 0) return bp.concLow;
      const ratio = (target - bp.ispuLow) / ispuRange;
      return Math.round(bp.concLow + ratio * (bp.concHigh - bp.concLow));
    }
  }
  return 500;
}

const aqiToPm25 = (v) => aqiToConcentration(v, PM25_BREAKPOINTS);
const aqiToSO2  = (v) => aqiToConcentration(v, SO2_BREAKPOINTS);
const aqiToO3   = (v) => aqiToConcentration(v, O3_BREAKPOINTS);
const aqiToNO2  = (v) => aqiToConcentration(v, NO2_BREAKPOINTS);

const evaluateParameter = (type, value) => {
  const catFor = (ispu) => getAQICategory(ispu);
  switch (type) {
    case 'pm25': { const i = calculateISPUFromPM25(value); const c = catFor(i); return { status: c.category, color: c.color, ispu: i }; }
    case 'pm10': { const i = calculateISPUFromPM10(value); const c = catFor(i); return { status: c.category, color: c.color, ispu: i }; }
    case 'co':   { const i = calculateISPUFromCO(value);   const c = catFor(i); return { status: c.category, color: c.color, ispu: i }; }
    case 'so2':  { const i = calculateISPUFromSO2(value);  const c = catFor(i); return { status: c.category, color: c.color, ispu: i }; }
    case 'o3':   { const i = calculateISPUFromO3(value);   const c = catFor(i); return { status: c.category, color: c.color, ispu: i }; }
    case 'no2':  { const i = calculateISPUFromNO2(value);  const c = catFor(i); return { status: c.category, color: c.color, ispu: i }; }
    case 'temperature':
      if (value == null) return { status: 'unknown', color: '#CCCCCC' };
      if (value >= 24 && value <= 26) return { status: 'ideal', color: '#0066CC' };
      if (value >= 20 && value <= 28) return { status: 'normal', color: '#00E400' };
      if (value >= 18 && value <= 30) return { status: 'sedang', color: '#FFFF00' };
      return { status: 'tidak_ideal', color: '#FF7E00' };
    case 'humidity':
      if (value == null) return { status: 'unknown', color: '#CCCCCC' };
      if (value >= 40 && value <= 60) return { status: 'ideal', color: '#0066CC' };
      if (value >= 30 && value <= 70) return { status: 'normal', color: '#00E400' };
      if (value >= 20 && value <= 80) return { status: 'sedang', color: '#FFFF00' };
      return { status: 'tidak_ideal', color: '#FF7E00' };
    default:
      return { status: 'unknown', color: '#CCCCCC' };
  }
};

module.exports = {
  calculateISPUFromPM25,
  calculateISPUFromPM10,
  calculateISPUFromCO,
  calculateISPUFromSO2,
  calculateISPUFromO3,
  calculateISPUFromNO2,
  calculateAQI,
  getAQICategory,
  evaluateParameter,
  aqiToPm25,
  aqiToSO2,
  aqiToO3,
  aqiToNO2,
  calculateAQIFromPM25: (pm25) => {
    const ispu = calculateISPUFromPM25(pm25);
    if (ispu == null) {
      const cat = getAQICategory(null);
      return { aqi: null, category: cat.category, color: cat.color };
    }
    const cat = getAQICategory(ispu);
    return { aqi: ispu, category: cat.category, color: cat.color };
  },
};