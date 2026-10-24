perbaikan

error
- ~~error Ketika edit Gedung dan refresh di dashboard~~
- ~~error Ketika hapus ruangan dan refresh di dashboard~~

perbaikan:
- ~~perbaikan Ketika menghapus ruangan di mode filter, itu filter nya masih di Gedung yg mau di hapus, tpi content nya menampilkan ruangan yg ada di semua Gedung, hrs nya ya content nya masih di filter yg terpilih~~
- ~~Ketika tambah ruangan, tidak langsung muncul di dashboard, harus di refresh dlu~~
- ~~nama Gedung di dashboard over margin~~
- ~~font pada rekomendasi Kesehatan diperhalus~~
- ~~Ketika baru tambah ruangan di Gedung, Ketika next nya ingin tambah ruanngan, pilihan Gedung langsung menampilkan ke pilihan yg paling atas, hrsnya muncul pilih Gedung~~
- ~~nama Gedung keluar margin di halaman detail ruangan~~

tambahan feature:
- ~~lupa password: tambahkan email admin~~

======================================================================================================================

22 10 2026

*STATUS AKTIF RUANGAN DAN ALAT IOT*

~~perjelas mengenasi sebenarnya status aktif dan tidak aktif itu buat apa, dan yang menandakan status aktif atau tidak aktif nya itu kan alat iot, bukan ruangan nya, jadi dibuat terintegrasi:~~
- ~~ketika ruangan dinonaktifkan maka akan menampilkan ruangan itu nonaktif~~
- ~~tapi ketika yang dinonaktifkan adalah alatnya, maka seluruh ruangan yang memakai alat itu maupun di halaman kelola ruangan dan dashboard ya menjadi nonaktif dan tidak bisa di aktifkan~~
- ~~pikirkan pengaruh hidup matinya server backend dan iot terhadap aktif nonaktifnya ruangan/alat iot~~

*AUTH ADMIN*
- ~~hilangkan warn ketika password tidak sesuai di auth admin~~
- ~~perbaiki snackbar ketika credential tidak tepat~~
- ~~hilangkan lingkaran load ketika login, lupa password ketika memasukan email, reset parword~~


*CATCH*

~~catch Ketika data mati~~
- ~~perbaikan tampilan dashboard catch nya Ketika server atau data mati di kedua mode~~
- ~~tambah juga catch nya Ketika data dimatikan, aneh nya Ketika di refresh akan menampilkan data sebelumnya sepersekiat detik, di buat langusng catch nya aja~~
- ~~catch Ketika login tapi server atau data mati~~
- ~~catch Ketika hapus Gedung tpi masih ada ruangan yg terkait~~

~~kondisi catch saat server mati:~~

~~PENGUNJUNG~~

1. ~~halaman login sebagai pengujung~~
    ~~- saat klik login~~

2. ~~dashboard~~
    ~~- saat klik refresh tampilkan catch snack bar, konten tetap ada~~

~~ADMIN~~

1. ~~halaman auth admin~~ 
    ~~- saat klik login~~
    ~~- saat klik reset password~~

2. ~~halaman lupa password~~
    ~~- saat kllik kirim link reset~~

3. ~~halaman reset passwrod
    ~~- saat klik reset password~~

4. ~~dashboard~~
    ~~- saat refresh~~

5. ~~room detil~~
    ~~- saat klik tombol refresh~~
    ~~- saat klik tombol refresh grafik~~

6. ~~building management~~
    ~~- saat klik rombol refresh~~
    ~~- saat klik tombol simpan gedung~~
    ~~- saat klik tombol hapus gedung (masih ada ruangan yang terkait juga)~~
    ~~- saat klik tombol simpan perubahan~~

7. room management
    ~~- saat klik tombol refresh~~
    ~~- saat klik sombol simpan ruangan~~
    ~~- saat klik tombol simpan perubahan~~
    ~~- saat klik tombol hapus~~

8. ~~iot device management~~
    ~~- saat klik tombol refresh~~
    ~~- saat klik sombol simpan device~~
    ~~- saat klik tombol simpan perubahan~~
    ~~- saat klik tombol hapus~~

9. ~~profil admin~~
    ~~- saat klik tombol simpan perubahan~~
    ~~- saat klik tombol ganti passwrord~~

*FITUR*

- perlengkap ambang batas tiap partikel, perbaiki jadi lebih bagus
- perbaiki ambang batas simuasi pada siang dan malam
- tambah halaman yang dapat mengetahui aktif atau tidak nya server atau alat iot yang ada
- hilangkan drawer di kanan atas pada dashboard

*REFRESH*

- perbaiki ketika device pada ruangan diganti, ketika klik tombol refresh tidak langsung mengganti data, harus tunggu 30 detik dulu
- katana refresh pada room detil tidak bekerja

*SORTING*

- perbaiki sorting alphabet pada dashbaord

*DASHBOARD*

- over margin keterangan terakhir update