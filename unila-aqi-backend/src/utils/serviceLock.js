/**
 * Service lock — memastikan hanya SATU siklus service
 * (simulation / iot) yang berjalan pada satu waktu.
 *
 * Tujuan: output terminal tidak saling memotong antar service.
 *
 * Cara kerja:
 *   - Setiap pemanggil `runExclusive(fn)` mengantre pada promise chain.
 *   - `fn` dijalankan setelah semua pemanggil sebelumnya selesai.
 *   - Jika `fn` melempar error, promise tetap resolve (tidak merusak chain).
 */

let chain = Promise.resolve();

function runExclusive(fn) {
  const run = chain.then(fn, fn); // jalankan fn baik chain resolve maupun reject
  // chain berikutnya menunggu `run` selesai (success/fail), tanpa
  // meneruskan rejection agar 1 error tidak "meracuni" pemanggil berikutnya.
  chain = run.then(
    () => undefined,
    () => undefined
  );
  return run;
}

module.exports = { runExclusive };