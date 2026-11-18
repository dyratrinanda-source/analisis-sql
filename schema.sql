CREATE TABLE users (
    id_user  INTEGER PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    email    VARCHAR(100) NOT NULL,
    role     VARCHAR(20)  NOT NULL         
);

CREATE TABLE katalog_layanans (
    id_katalog_layanan INTEGER PRIMARY KEY,
    nama_layanan       VARCHAR(100) NOT NULL
);

CREATE TABLE jadwal_konsultasis (
    id_jadwal_konsultasi INTEGER PRIMARY KEY,
    id_user       INTEGER NOT NULL,
    nama_klien    VARCHAR(100) NOT NULL,
    jenis_layanan VARCHAR(100) NOT NULL,
    tanggal       DATE NOT NULL,
    jam_mulai     TIME NOT NULL,
    jam_selesai   TIME NOT NULL,
    status        VARCHAR(20) NOT NULL,    
    FOREIGN KEY (id_user) REFERENCES users(id_user)
);

CREATE TABLE pengajuans (
    id_pengajuan  INTEGER PRIMARY KEY,
    id_user       INTEGER NOT NULL,
    nomor_tiket   VARCHAR(30) NOT NULL,
    jenis_layanan VARCHAR(100) NOT NULL,
    status        VARCHAR(20) NOT NULL,    
    created_at    DATETIME NOT NULL,
    FOREIGN KEY (id_user) REFERENCES users(id_user)
);

CREATE TABLE pengajuan_trackings (
    id_pengajuan_tracking INTEGER PRIMARY KEY,
    id_pengajuan INTEGER NOT NULL,
    step         INTEGER NOT NULL,          
    nama_tahap   VARCHAR(60) NOT NULL,
    is_completed TINYINT NOT NULL,
    created_at   DATETIME NOT NULL,
    FOREIGN KEY (id_pengajuan) REFERENCES pengajuans(id_pengajuan)
);

CREATE TABLE berkas_kliens (
    id_berkas_klien     INTEGER PRIMARY KEY,
    id_user             INTEGER NOT NULL,
    id_pengajuan        INTEGER NOT NULL,
    jenis_dokumen       VARCHAR(50) NOT NULL,
    status              VARCHAR(20) NOT NULL, 
    created_at          DATETIME NOT NULL,
    diverifikasi_pada   DATETIME NULL,
    id_user_verifikator INTEGER NULL,
    FOREIGN KEY (id_user) REFERENCES users(id_user),
    FOREIGN KEY (id_pengajuan) REFERENCES pengajuans(id_pengajuan),
    FOREIGN KEY (id_user_verifikator) REFERENCES users(id_user)
);
