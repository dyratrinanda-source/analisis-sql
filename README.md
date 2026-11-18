# Analisis Operasional & Efisiensi Layanan Kantor Notaris (SQL)

Analisis SQL untuk mengukur durasi layanan, menemukan hambatan proses, dan membaca pola konsultasi pada sistem manajemen kantor notaris (skripsi S1 Sistem Informasi).

> **Catatan data: SIMULASI.** Seluruh data di folder ini fiktif, dibuat oleh `generate_data.py` (random seed 42) di atas skema database sistem. Tidak ada data klien atau kantor notaris nyata. Pola yang muncul dipengaruhi parameter di generator, jadi hasilnya menunjukkan **teknik analisis**, bukan temuan dari kantor notaris sebenarnya.

## Pertanyaan bisnis

1. Berapa lama tiap jenis layanan selesai, dan tahap mana yang paling menghambat?
2. Pengajuan aktif mana yang tidak bergerak dan perlu ditindaklanjuti?
3. Kapan konsultasi paling ramai, dan seberapa sering jadwal bentrok?
4. Apakah beban verifikasi dokumen merata antar staf?

## Data

| Tabel | Isi | Baris |
|---|---|---|
| `users` | klien, staf, notaris | 123 |
| `katalog_layanans` | daftar layanan | 24 |
| `jadwal_konsultasis` | jadwal konsultasi | 420 |
| `pengajuans` | tiket layanan | 320 |
| `pengajuan_trackings` | waktu tiap tahap selesai (6 tahap) | 1.889 |
| `berkas_kliens` | dokumen klien dan verifikasinya | 1.273 |

Periode data: Januari sampai 30 September 2026.

## Teknik SQL

CTE, window function (`LAG`, `ROW_NUMBER`, `RANK`, `SUM() OVER`), self join, agregasi dengan `CASE`, dan fungsi tanggal (`DATEDIFF`, `TIMESTAMPDIFF`).

## Temuan (dari data simulasi)

| # | Temuan | Angka |
|---|---|---|
| 1 | Layanan paling lama: **Pendirian PT PMA**. Tercepat: **Pendirian CV** | 25,4 hari vs 11,9 hari |
| 2 | Tahap paling lama adalah **menunggu dokumen terbit setelah pendaftaran Kemenkumham** | 7,3 hari, 43,8% dari total waktu |
| 3 | Pada 7 pengajuan aktif, tidak ada pergerakan lebih dari 7 hari, mayoritas di tahap Pendaftaran Kemenkumham | 10 sampai 19 hari diam |
| 4 | Konsultasi memuncak pada **Selasa dan Kamis** dan jam **10.00 dan 14.00** | Selasa 24,0%, Kamis 22,9%; jam 14: 24,0%, jam 10: 22,4% |
| 5 | Jadwal yang waktunya beririsan dengan jadwal lain (satu notaris) | 129 dari 352 jadwal aktif (36,6%) |
| 6 | Beban verifikasi tidak merata: Staf 1 memegang dua kali lipat beban Staf 2, yang lebih lambat dan lebih sering meminta revisi | 67,2% vs 32,8%; 13,4 vs 28,0 jam; revisi 10,0% vs 17,3% |

Catatan baca:
- Durasi layanan dihitung hanya dari pengajuan berstatus **Selesai**. Pengajuan yang masih berjalan tidak dihitung agar rata-rata tidak bias.
- Angka tahap (temuan 2) adalah lama dari tahap sebelumnya sampai tahap itu tercapai.
- Temuan 5 mengasumsikan satu notaris menerima satu klien pada satu waktu. Tingginya angka ini sebagian akibat jadwal simulasi dibuat tanpa kontrol slot.

## Rekomendasi

- **Pengingat otomatis ke klien** untuk pengajuan yang tidak bergerak lebih dari 7 hari, dan pantau status pendaftaran Kemenkumham secara berkala.
- **Kuota slot konsultasi** per jam, dan batasi jumlah konsultasi pada Selasa dan Kamis sore, supaya jadwal tidak bertabrakan.
- **Ratakan beban verifikasi** antar staf, dan cek penyebab selisih waktu dan tingkat revisi antar staf (misalnya perbedaan checklist).

## Cara menjalankan (MySQL 8.0+)

```sql
CREATE DATABASE notaris_analisis;
USE notaris_analisis;
SOURCE schema.sql;
SOURCE seed_data.sql;
SOURCE analisis.sql;
```

Untuk membuat ulang datanya: `python generate_data.py`.

Query diverifikasi dengan menjalankan seluruh isi `analisis.sql` pada data ini. Hasil lengkap ada di `hasil_query.txt`.

## Batasan

- Data simulasi, sehingga angka tidak dapat digeneralisasi ke kantor notaris nyata.
- Tidak ada uji statistik, hanya analisis deskriptif.
- Tidak ada data biaya atau tarif layanan.
