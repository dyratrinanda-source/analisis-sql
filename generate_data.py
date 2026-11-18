"""
Membuat DATA SIMULASI untuk analisis operasional kantor notaris.
Semua data fiktif. Hasil dibuat dengan random seed tetap (42) sehingga
bisa direproduksi: python generate_data.py  ->  seed_data.sql

Asumsi pembangkitan data ada di bagian PARAMETER di bawah. Pola yang muncul
di hasil analisis dipengaruhi parameter ini, jadi insight bersifat ilustrasi
teknik analisis, BUKAN temuan dari kantor notaris nyata.
"""
import random
from datetime import datetime, timedelta, date

random.seed(42)
SNAPSHOT = datetime(2026, 9, 30, 17, 0)

# ---------------- PARAMETER ----------------
TAHAP = {1: "Pengajuan dan Berkas Diterima", 2: "Verifikasi Syarat Dokumen",
         3: "Pembuatan Draft Akta", 4: "Penandatangan Akta",
         5: "Pendaftaran Kemenkumham", 6: "Dokumen Selesai"}

# layanan: (bobot, rata-rata hari antar tahap 1->2, 2->3, 3->4, 4->5, 5->6)
LAYANAN = {
    "Pendirian PT (Lokal)":        (0.25, [1.5, 2.0, 2.5, 2.0, 8.0]),
    "Pendirian PT PMA":            (0.08, [2.0, 3.0, 3.0, 3.0, 14.0]),
    "Pendirian CV":                (0.20, [1.0, 1.5, 2.0, 1.5, 5.0]),
    "Perubahan Akta Terbit SK":    (0.15, [1.5, 2.0, 2.0, 2.0, 7.0]),
    "Pembubaran PT":               (0.07, [2.0, 2.5, 2.5, 2.5, 10.0]),
    "Akta Jual Beli Saham":        (0.10, [2.0, 3.0, 4.0, 6.0, 6.0]),
    "Perjanjian Jual Beli Saham":  (0.08, [1.5, 2.0, 3.0, 3.0, 4.0]),
    "Akta Cabang":                 (0.07, [1.0, 1.5, 2.0, 2.0, 6.0]),
}
KATALOG = ["Pendirian PT (Lokal)", "Pendirian PT PMA", "Pendirian CV", "Pendirian Firma",
    "Pendirian Persekutuan Perdata", "Pendirian Yayasan", "Pendirian Perkumpulan",
    "Perubahan Akta Terbit SK", "Perubahan Akta Terbit SK + SP", "Perubahan Akta Terbit SP + SK + SP",
    "Perubahan Akta Terbit SP + SP", "Perubahan CV", "Perubahan Akta PT PMA Terbit SK",
    "Perubahan Akta PT PMA Terbit SP", "Perubahan Akta Terbit PT PMA SK + SP",
    "Perubahan Akta Terbit PT PMA SP + SK + SP", "Pembubaran PT", "Pembubaran CV",
    "Penonaktifan PT", "Akta Jual Beli Saham", "Perjanjian Jual Beli Saham", "Buka Blokir",
    "Akta Perubahan PT Perorangan ke PT Biasa", "Akta Cabang"]
N_KLIEN, N_PENGAJUAN, N_JADWAL = 120, 320, 420
P_TERTAHAN = 0.07          # peluang pengajuan tertahan (berkas klien kurang)
DOKUMEN = ["KTP", "NPWP", "KK", "Akta Pendirian", "SK Kemenkumham", "Surat Kuasa"]
VERIFIKATOR_BOBOT = {1: 0.65, 2: 0.35}          # staff 1 menerima 65% dokumen
VERIFIKATOR_JAM = {1: 14.0, 2: 30.0}            # rata-rata jam verifikasi
P_REVISI = {1: 0.10, 2: 0.17}
# -------------------------------------------

def pilih(d):  # d: {item: bobot}
    r, acc = random.random() * sum(d.values()), 0
    for k, v in d.items():
        acc += v
        if r <= acc: return k
    return k

def q(v):
    if v is None: return "NULL"
    if isinstance(v, (int, float)): return str(v)
    return "'" + str(v).replace("'", "''") + "'"

def dt(x): return x.strftime("%Y-%m-%d %H:%M:%S")

rows = {t: [] for t in ["users", "katalog", "jadwal", "pengajuan", "tracking", "berkas"]}

# users
rows["users"] += [(1, "Staff Verifikasi 1", "staff1@example.com", "staff"),
                  (2, "Staff Verifikasi 2", "staff2@example.com", "staff"),
                  (3, "Notaris", "notaris@example.com", "notaris")]
for i in range(N_KLIEN):
    rows["users"].append((4 + i, f"Klien {i+1:03d}", f"klien{i+1:03d}@example.com", "klien"))
klien_ids = [4 + i for i in range(N_KLIEN)]
for i, n in enumerate(KATALOG, 1): rows["katalog"].append((i, n))

# pengajuan, tracking, berkas
tid = bid = 0
awal, akhir = datetime(2026, 1, 5, 9), datetime(2026, 9, 27, 16)
for pid in range(1, N_PENGAJUAN + 1):
    layanan = pilih({k: v[0] for k, v in LAYANAN.items()})
    gaps = LAYANAN[layanan][1]
    start = awal + timedelta(seconds=random.random() * (akhir - awal).total_seconds())
    start = start.replace(hour=random.randint(8, 16), minute=random.randint(0, 59), second=0)
    uid = random.choice(klien_ids)
    t, reached = start, [(1, start)]
    tertahan_di = random.randint(2, 5) if random.random() < P_TERTAHAN else None
    for step in range(2, 7):
        g = max(0.2, random.gammavariate(2, gaps[step - 2] / 2))
        if tertahan_di == step: g += random.uniform(10, 25)
        t = t + timedelta(days=g)
        if t > SNAPSHOT: break
        reached.append((step, t))
    selesai = len(reached) == 6
    rows["pengajuan"].append((pid, uid, f"TKT-{start:%y%m%d}-{pid:04d}", layanan,
                              "Selesai" if selesai else "Aktif", dt(start)))
    for step, ts in reached:
        tid += 1
        rows["tracking"].append((tid, pid, step, TAHAP[step], 1, dt(ts)))
    for d in random.sample(DOKUMEN, random.randint(3, 5)):
        bid += 1
        up = start + timedelta(hours=random.uniform(0, 6))
        v = pilih(VERIFIKATOR_BOBOT)
        if len(reached) >= 2:
            ver = up + timedelta(hours=max(1, random.gammavariate(2, VERIFIKATOR_JAM[v] / 2)))
            ver = min(ver, SNAPSHOT)
            st = "Perlu Perbaikan" if random.random() < P_REVISI[v] else "Disetujui"
            rows["berkas"].append((bid, uid, pid, d, st, dt(up), dt(ver), v))
        else:
            rows["berkas"].append((bid, uid, pid, d, "Pending", dt(up), None, None))

# jadwal konsultasi: Selasa & Kamis lebih ramai, jam 10 dan 14 paling ramai
hari_w = {0: .13, 1: .24, 2: .17, 3: .24, 4: .22}
jam_w = {9: .10, 10: .24, 11: .10, 13: .10, 14: .24, 15: .13, 16: .09}
for jid in range(1, N_JADWAL + 1):
    while True:
        d = date(2026, 1, 5) + timedelta(days=random.randint(0, 268))
        if d.weekday() in hari_w and random.random() < hari_w[d.weekday()] / .24: break
    jam = pilih(jam_w)
    durasi = random.choice([60, 60, 90])
    mulai = datetime(d.year, d.month, d.day, jam, random.choice([0, 0, 30]))
    selesai = mulai + timedelta(minutes=durasi)
    if d >= date(2026, 9, 25): st = random.choice(["menunggu", "disetujui"])
    else: st = "selesai" if random.random() < 0.85 else "ditolak"
    uid = random.choice(klien_ids)
    rows["jadwal"].append((jid, uid, f"Klien {uid-3:03d}", random.choice(list(LAYANAN)),
                           d.isoformat(), mulai.strftime("%H:%M:%S"), selesai.strftime("%H:%M:%S"), st))

def tulis(f, tabel, kolom, data, batch=200):
    for i in range(0, len(data), batch):
        vals = ",\n  ".join("(" + ", ".join(q(v) for v in r) + ")" for r in data[i:i+batch])
        f.write(f"INSERT INTO {tabel} ({kolom}) VALUES\n  {vals};\n")

with open("seed_data.sql", "w", encoding="utf-8") as f:
    f.write("-- DATA SIMULASI (fiktif). Dibuat oleh generate_data.py, seed=42.\n")
    tulis(f, "users", "id_user,name,email,role", rows["users"])
    tulis(f, "katalog_layanans", "id_katalog_layanan,nama_layanan", rows["katalog"])
    tulis(f, "jadwal_konsultasis", "id_jadwal_konsultasi,id_user,nama_klien,jenis_layanan,tanggal,jam_mulai,jam_selesai,status", rows["jadwal"])
    tulis(f, "pengajuans", "id_pengajuan,id_user,nomor_tiket,jenis_layanan,status,created_at", rows["pengajuan"])
    tulis(f, "pengajuan_trackings", "id_pengajuan_tracking,id_pengajuan,step,nama_tahap,is_completed,created_at", rows["tracking"])
    tulis(f, "berkas_kliens", "id_berkas_klien,id_user,id_pengajuan,jenis_dokumen,status,created_at,diverifikasi_pada,id_user_verifikator", rows["berkas"])
print({k: len(v) for k, v in rows.items()})
