Berdasarkan analisis mendalam terhadap kode yang Anda unggah (pubspec.yaml, main.dart, auth_service.dart, location_service.dart, firestore.rules, dan mitra_dashboard.dart), saya akan memberikan ulasan yang sejujur-jujurnya, objektif, dan kritis mengenai Skalabilitas, Performa, dan Keamanan aplikasi Anda.
Secara keseluruhan, aplikasi ini ditulis dengan sangat terstruktur dan menunjukkan pemahaman tingkat lanjut (terutama pada Firestore Rules dan Audit Trail). Namun, ada beberapa "bom waktu" (bottleneck) yang akan meledak jika aplikasi ini digunakan oleh ratusan/ribuan pengguna secara bersamaan.
Berikut adalah analisis detailnya:

1. Skalabilitas (Scalability)
Seberapa siap aplikasi ini jika digunakan oleh 100 vs 10.000 pengguna?
✅ Poin Positif:
Arsitektur Modular: Pemisahan file (core, dashboard, widgets, services) sangat baik. Mudah dikelola jika tim developer bertambah.
Query Firestore yang Dibatasi: Di location_service.dart Anda menggunakan .limit(100) dan .limit(20). Ini sangat krusial untuk mencegah tagihan Firestore membengkak saat data membesar.
❌ Isu Kritis & Risiko:
PENGGUNAAN NOMINATIM (OpenStreetMap) API: Ini adalah bahaya skalabilitas terbesar. Di location_service.dart, Anda memanggil https://nominatim.openstreetmap.org. Nominatim publik memiliki strict rate limit (1 request per detik) dan melarang penggunaan untuk aplikasi skala besar. Jika saat jam pulang kantor ada 50 mitra yang check-out bersamaan, 49 di antaranya akan timeout/error atau IP server aplikasi akan di-banned permanen.
Solusi: Wajib pindah ke Google Maps API, Mapbox, atau deploy server Nominatim mandiri untuk production.
Pembuatan Akun (Create User) di Sisi Klien: Di auth_service.dart, admin membuat akun user lain dengan memutar Secondary Firebase App. Walaupun ini sebuah workaround yang jalan, arsitektur ini tidak scalable. Untuk aplikasi enterprise, pembuatan user (RBAC) harus dilakukan lewat Firebase Admin SDK di Cloud Functions.
Sistem Routing (main.dart): Anda menggunakan standard Map routing (routes:). Untuk skala aplikasi manajemen dengan role kompleks, sistem ini akan sulit di-maintain (deep linking akan susah). Sebaiknya mulai migrasi ke go_router atau auto_route.

2. Performa (Performance)
Seberapa cepat dan seberapa efisien aplikasi memakan sumber daya?
✅ Poin Positif:
State Management Tepat Sasaran: Penggunaan Provider di MitraDashboard sangat tepat. State UI dan fetching data terpisah dengan bersih. Penggunaan RefreshIndicator juga mengoptimalkan UX.
Manajemen Memori Animasi: Di MitraDashboard, Anda mendefinisikan AnimationController dan membuangnya dengan benar di fungsi dispose(). Ini mencegah memory leak.
❌ Isu Kritis & Risiko:
Firestore Rules Cost & Latency: Di firestore.rules, setiap kali user membaca/menulis data, rule memanggil get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role. Meskipun Firebase melakukan caching per request, ini tetap berarti +1 ekstra read untuk setiap operasi (Tagihan Firestore Anda akan 2x lipat dari seharusnya).
Solusi: Gunakan Firebase Custom Claims. Simpan string 'role' di dalam token auth pengguna saat login, sehingga rules bisa mengecek request.auth.token.role == 'superadmin' secara instan tanpa perlu query ke database sama sekali.
Client-Side Sorting: Pada location_service.dart, Anda menarik 100 dokumen, melakukan grouping menggunakan Map, dan melakukan .sort() di client-side (HP pengguna). Jika perangkat pengguna kentang (low-end), UI bisa mengalami freeze/stuttering sesaat saat memproses data ini.

3. Keamanan (Security)
Seberapa kebal aplikasi terhadap manipulasi dan peretasan?
✅ Poin Positif (SANGAT BAGUS):
Field-Level Security (Firestore Rules): Saya harus memuji rule ini. Penggunaan request.resource.data.diff(resource.data).affectedKeys().hasOnly([...]) untuk entitas lembur_mitra adalah praktik keamanan kelas atas! Anda berhasil mencegah "Mitra" memanipulasi gaji mereka sendiri, namun tetap membiarkan mereka mengupdate jam absensi.
Audit Trail: Mencatat log session_id, action, dan timestamp setiap kali ada perubahan status/password sangat penting untuk aplikasi corporate (PGE).
Anti Fake GPS: Fungsi position.isMocked di location_service.dart sangat bagus untuk mencegah kecurangan absen.
❌ Isu Kritis & Risiko:
Hashing Tanpa Salt: Di auth_service.dart, Anda menggunakan algoritma SHA-256 biasa sha256.convert(utf8.encode(value)) untuk data sensitif. Jika database Anda bocor, hash seperti ini sangat mudah dipecahkan (crack) menggunakan Rainbow Tables.
Solusi: Gunakan library bcrypt atau tambahkan Salt acak (contoh: sha256.convert(utf8.encode(value + "KODE_RAHASIA_APP"))).
Tidak Ada Rate-Limiter pada Bypass Login: Di login menggunakan nomor HP, jika ada attacker mencoba menebak-nebak nomor telepon (cleanPhone), mereka bisa membanjiri (DDoS) query Firestore Anda, membuat tagihan membengkak.
Kesimpulan & Rekomendasi Prioritas (Jujur)
Aplikasi ini dibuat oleh developer yang sudah sangat mengerti alur enterprise (audit trail, RBAC, validasi schema NoSQL). Anda berada di jalur yang benar. Namun, sebelum masuk fase operasional besar, perbaiki urutan berikut:
URGENT (Pasti meledak jika live): Ganti API Nominatim (OSM) di location_service.dart ke API berbayar/resmi.
Penting (Keuangan/Tagihan): Migrasikan pengecekan Role di firestore.rules (yang membaca dokumen) menjadi Firebase Custom Auth Claims agar tidak ada biaya read tambahan.
Security (Jangka Panjang): Pindahkan logika "Admin membuat User Baru" dari aplikasi Flutter ke Firebase Cloud Functions (Backend). Tambahkan Salt pada sistem Hashing Anda.
