-- =====================================================================
-- ANALISIS OPERASIONAL & EFISIENSI LAYANAN KANTOR NOTARIS
-- Dialek: MySQL 8.0+ (CTE & window function). Data: SIMULASI (lihat README).
-- Tanggal acuan data (snapshot): 2026-09-30
-- =====================================================================

-- Q1. Berapa lama tiap jenis layanan selesai? (CTE + agregasi)
WITH durasi AS (
    SELECT p.id_pengajuan, p.jenis_layanan,
           MIN(t.created_at) AS mulai,
           MAX(t.created_at) AS selesai
    FROM pengajuans p
    JOIN pengajuan_trackings t ON t.id_pengajuan = p.id_pengajuan
    WHERE p.status = 'Selesai'
    GROUP BY p.id_pengajuan, p.jenis_layanan
)
SELECT jenis_layanan,
       COUNT(*)                              AS jumlah_selesai,
       ROUND(AVG(DATEDIFF(selesai, mulai)), 1) AS rata_rata_hari,
       MIN(DATEDIFF(selesai, mulai))         AS tercepat_hari,
       MAX(DATEDIFF(selesai, mulai))         AS terlama_hari
FROM durasi
GROUP BY jenis_layanan
ORDER BY rata_rata_hari DESC;


-- Q2. Tahap mana yang paling lama? (LAG: selisih waktu antar tahap)
-- Catatan baca: angka = lama dari tahap sebelumnya sampai tahap ini tercapai.
-- Mis. 'Dokumen Selesai' = lama menunggu setelah Pendaftaran Kemenkumham sampai dokumen terbit.
WITH tahap AS (
    SELECT t.id_pengajuan, t.step, t.nama_tahap, t.created_at,
           LAG(t.created_at) OVER (PARTITION BY t.id_pengajuan ORDER BY t.step) AS waktu_tahap_sebelumnya
    FROM pengajuan_trackings t
    JOIN pengajuans p ON p.id_pengajuan = t.id_pengajuan
    WHERE p.status = 'Selesai'
),
lama AS (
    SELECT step, nama_tahap,
           TIMESTAMPDIFF(HOUR, waktu_tahap_sebelumnya, created_at) / 24.0 AS hari
    FROM tahap
    WHERE waktu_tahap_sebelumnya IS NOT NULL
)
SELECT step, nama_tahap,
       COUNT(*)                                             AS jumlah_data,
       ROUND(AVG(hari), 1)                                  AS rata_rata_hari,
       ROUND(100 * AVG(hari) / SUM(AVG(hari)) OVER (), 1)   AS porsi_dari_total_persen
FROM lama
GROUP BY step, nama_tahap
ORDER BY rata_rata_hari DESC;


-- Q3. Tahap penghambat utama untuk SETIAP layanan (LAG + RANK)
-- (tahap dengan waktu tunggu rata-rata terlama menuju tahap itu)
WITH tahap AS (
    SELECT p.jenis_layanan, t.step, t.nama_tahap, t.created_at,
           LAG(t.created_at) OVER (PARTITION BY t.id_pengajuan ORDER BY t.step) AS sebelumnya
    FROM pengajuan_trackings t
    JOIN pengajuans p ON p.id_pengajuan = t.id_pengajuan
    WHERE p.status = 'Selesai'
),
rata AS (
    SELECT jenis_layanan, nama_tahap,
           AVG(TIMESTAMPDIFF(HOUR, sebelumnya, created_at) / 24.0) AS rata_hari
    FROM tahap
    WHERE sebelumnya IS NOT NULL
    GROUP BY jenis_layanan, nama_tahap
),
peringkat AS (
    SELECT jenis_layanan, nama_tahap, rata_hari,
           RANK() OVER (PARTITION BY jenis_layanan ORDER BY rata_hari DESC) AS peringkat
    FROM rata
)
SELECT jenis_layanan, nama_tahap AS tahap_terlama, ROUND(rata_hari, 1) AS rata_rata_hari
FROM peringkat
WHERE peringkat = 1
ORDER BY rata_hari DESC;


-- Q4. Pengajuan aktif yang "diam" lebih dari 7 hari (ROW_NUMBER)
WITH terakhir AS (
    SELECT t.id_pengajuan, t.nama_tahap, t.created_at,
           ROW_NUMBER() OVER (PARTITION BY t.id_pengajuan ORDER BY t.step DESC) AS urutan
    FROM pengajuan_trackings t
)
SELECT p.nomor_tiket, p.jenis_layanan,
       tr.nama_tahap AS tahap_terakhir,
       DATEDIFF('2026-09-30', tr.created_at) AS hari_tidak_bergerak
FROM pengajuans p
JOIN terakhir tr ON tr.id_pengajuan = p.id_pengajuan AND tr.urutan = 1
WHERE p.status = 'Aktif'
  AND DATEDIFF('2026-09-30', tr.created_at) > 7
ORDER BY hari_tidak_bergerak DESC;


-- Q5a. Pola konsultasi: hari apa paling ramai?
SELECT CASE DAYOFWEEK(tanggal)
           WHEN 2 THEN 'Senin' WHEN 3 THEN 'Selasa' WHEN 4 THEN 'Rabu'
           WHEN 5 THEN 'Kamis' WHEN 6 THEN 'Jumat' END AS hari,
       COUNT(*) AS jumlah_konsultasi,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS persen
FROM jadwal_konsultasis
GROUP BY DAYOFWEEK(tanggal)
ORDER BY jumlah_konsultasi DESC;

-- Q5b. Pola konsultasi: jam berapa paling ramai?
SELECT HOUR(jam_mulai) AS jam_mulai,
       COUNT(*) AS jumlah_konsultasi,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS persen
FROM jadwal_konsultasis
GROUP BY HOUR(jam_mulai)
ORDER BY jumlah_konsultasi DESC;


-- Q6. Jadwal konsultasi yang bentrok (SELF JOIN: jadwal vs jadwal lain di hari sama)
SELECT a.tanggal,
       a.id_jadwal_konsultasi AS jadwal_a, a.jam_mulai AS mulai_a, a.jam_selesai AS selesai_a,
       b.id_jadwal_konsultasi AS jadwal_b, b.jam_mulai AS mulai_b, b.jam_selesai AS selesai_b
FROM jadwal_konsultasis a
JOIN jadwal_konsultasis b
  ON  a.tanggal = b.tanggal
  AND a.id_jadwal_konsultasi < b.id_jadwal_konsultasi
  AND a.jam_mulai < b.jam_selesai
  AND b.jam_mulai < a.jam_selesai
WHERE a.status <> 'ditolak' AND b.status <> 'ditolak'
ORDER BY a.tanggal;

-- Q6b. Ringkasan: berapa persen jadwal yang terlibat bentrok?
WITH bentrok AS (
    SELECT a.id_jadwal_konsultasi AS id FROM jadwal_konsultasis a
    JOIN jadwal_konsultasis b
      ON a.tanggal = b.tanggal AND a.id_jadwal_konsultasi <> b.id_jadwal_konsultasi
     AND a.jam_mulai < b.jam_selesai AND b.jam_mulai < a.jam_selesai
    WHERE a.status <> 'ditolak' AND b.status <> 'ditolak'
    GROUP BY a.id_jadwal_konsultasi
)
SELECT (SELECT COUNT(*) FROM bentrok) AS jadwal_terlibat_bentrok,
       (SELECT COUNT(*) FROM jadwal_konsultasis WHERE status <> 'ditolak') AS total_jadwal_aktif,
       ROUND(100.0 * (SELECT COUNT(*) FROM bentrok)
             / (SELECT COUNT(*) FROM jadwal_konsultasis WHERE status <> 'ditolak'), 1) AS persen_bentrok;


-- Q7. Beban kerja & kecepatan staf verifikasi
SELECT u.name AS staf,
       COUNT(*) AS dokumen_diverifikasi,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS porsi_beban_persen,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, b.created_at, b.diverifikasi_pada)), 1) AS rata_rata_jam_verifikasi,
       ROUND(100.0 * SUM(CASE WHEN b.status = 'Perlu Perbaikan' THEN 1 ELSE 0 END) / COUNT(*), 1) AS persen_perlu_perbaikan
FROM berkas_kliens b
JOIN users u ON u.id_user = b.id_user_verifikator
WHERE b.diverifikasi_pada IS NOT NULL
GROUP BY u.id_user, u.name
ORDER BY dokumen_diverifikasi DESC;


-- Q8. Volume pengajuan per bulan & perubahan dari bulan lalu (LAG)
WITH bulanan AS (
    SELECT SUBSTRING(created_at, 1, 7) AS bulan, COUNT(*) AS jumlah
    FROM pengajuans
    GROUP BY SUBSTRING(created_at, 1, 7)
)
SELECT bulan, jumlah,
       LAG(jumlah) OVER (ORDER BY bulan) AS bulan_lalu,
       ROUND(100.0 * (jumlah - LAG(jumlah) OVER (ORDER BY bulan))
             / LAG(jumlah) OVER (ORDER BY bulan), 1) AS perubahan_persen
FROM bulanan
ORDER BY bulan;
