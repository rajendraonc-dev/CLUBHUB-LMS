-- =====================================================================
-- ClubHub LMS - Skema Basis Data MySQL 8.x
-- Eksekusi: mysql -u root -p < schema.sql
-- =====================================================================
CREATE DATABASE IF NOT EXISTS clubhub_lms
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE clubhub_lms;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS ai_chat_logs, submissions, modules, users, tracks;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. TRACKS (jalur penjurusan / kategori lab)
CREATE TABLE tracks (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  title       VARCHAR(100) NOT NULL,
  description TEXT         NULL,
  category    ENUM('webdev','cybersecurity','uiux','tjkt','robotik') NOT NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tracks_title (title),
  KEY idx_tracks_category (category)
) ENGINE=InnoDB;

-- 2. USERS
CREATE TABLE users (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name           VARCHAR(100) NOT NULL,
  email          VARCHAR(150) NOT NULL,
  password       VARCHAR(255) NOT NULL,              -- hash bcrypt/argon2, BUKAN teks asli
  role           ENUM('student','mentor','admin') NOT NULL DEFAULT 'student',
  track_interest INT UNSIGNED NULL,
  xp_points      INT UNSIGNED NOT NULL DEFAULT 0,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_xp (xp_points),
  CONSTRAINT fk_users_track FOREIGN KEY (track_interest)
    REFERENCES tracks(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 3. MODULES (materi / tantangan lab di dalam sebuah track)
CREATE TABLE modules (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  track_id    INT UNSIGNED NOT NULL,
  title       VARCHAR(150) NOT NULL,
  description TEXT         NULL,
  category    ENUM('coding','ctf','design','network','iot') NOT NULL,
  difficulty  ENUM('easy','medium','hard') NOT NULL DEFAULT 'easy',
  xp_reward   SMALLINT UNSIGNED NOT NULL DEFAULT 50,
  flag_hash   CHAR(64) NULL,                          -- SHA-256 dari flag CTF (flag asli tidak disimpan)
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_modules_track (track_id),
  CONSTRAINT fk_modules_track FOREIGN KEY (track_id)
    REFERENCES tracks(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_modules_xp CHECK (xp_reward BETWEEN 0 AND 1000)
) ENGINE=InnoDB;

-- 4. SUBMISSIONS
CREATE TABLE submissions (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        INT UNSIGNED NOT NULL,
  module_id      INT UNSIGNED NOT NULL,
  code_content   MEDIUMTEXT   NULL,
  flag_submitted VARCHAR(255) NULL,
  status         ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
  score          TINYINT UNSIGNED NOT NULL DEFAULT 0,
  submitted_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_sub_user_module (user_id, module_id),
  KEY idx_sub_status (status),
  CONSTRAINT fk_sub_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_sub_module FOREIGN KEY (module_id)
    REFERENCES modules(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_sub_score CHECK (score BETWEEN 0 AND 100),
  CONSTRAINT chk_sub_content CHECK (code_content IS NOT NULL OR flag_submitted IS NOT NULL)
) ENGINE=InnoDB;

-- 5. AI_CHAT_LOGS
CREATE TABLE ai_chat_logs (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     INT UNSIGNED NOT NULL,
  module_id   INT UNSIGNED NULL,
  prompt      TEXT NOT NULL,
  ai_response MEDIUMTEXT NOT NULL,
  timestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_chat_user_time (user_id, timestamp),
  CONSTRAINT fk_chat_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_chat_module FOREIGN KEY (module_id)
    REFERENCES modules(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- TRIGGER: tambah XP otomatis saat submission pertama yang diterima untuk modul tertentu
DELIMITER //
CREATE TRIGGER trg_award_xp AFTER INSERT ON submissions
FOR EACH ROW
BEGIN
  IF NEW.status = 'accepted' AND NOT EXISTS (
       SELECT 1 FROM submissions
       WHERE user_id = NEW.user_id AND module_id = NEW.module_id
         AND status = 'accepted' AND id <> NEW.id) THEN
    UPDATE users SET xp_points = xp_points +
      (SELECT xp_reward FROM modules WHERE id = NEW.module_id)
    WHERE id = NEW.user_id;
  END IF;
END//
DELIMITER ;

-- VIEW: papan peringkat (leaderboard XP)
CREATE OR REPLACE VIEW v_leaderboard AS
SELECT RANK() OVER (ORDER BY xp_points DESC) AS peringkat,
       id AS user_id, name, xp_points
FROM users WHERE role = 'student';

-- ======================= DATA SAMPEL =======================
INSERT INTO tracks (title, description, category) VALUES
 ('Web Development Fundamental', 'HTML, CSS, JavaScript, dan dasar backend.', 'webdev'),
 ('Cybersecurity CTF',           'Latihan Capture The Flag di lingkungan sandbox.', 'cybersecurity'),
 ('UI/UX Studio',                'Riset pengguna, wireframe, dan prototipe.', 'uiux'),
 ('Lab TJKT',                    'Simulasi jaringan, server, dan troubleshooting.', 'tjkt'),
 ('Robotik & IoT',               'Mikrokontroler, sensor, dan aktuator.', 'robotik');

-- Hash di bawah adalah PLACEHOLDER. Buat hash asli: PHP password_hash('...', PASSWORD_BCRYPT)
INSERT INTO users (name, email, password, role, track_interest, xp_points) VALUES
 ('Admin ClubHub',  'admin@clubhub.test',  '$2y$10$GANTI_DENGAN_HASH_PASSWORD_HASH_ASLI', 'admin',   NULL, 0),
 ('Mentor Rahmat',  'mentor@clubhub.test', '$2y$10$GANTI_DENGAN_HASH_PASSWORD_HASH_ASLI', 'mentor',  1,    0),
 ('Siswa Alya',     'alya@clubhub.test',   '$2y$10$GANTI_DENGAN_HASH_PASSWORD_HASH_ASLI', 'student', 2,    120),
 ('Siswa Bima',     'bima@clubhub.test',   '$2y$10$GANTI_DENGAN_HASH_PASSWORD_HASH_ASLI', 'student', 1,    80);

INSERT INTO modules (track_id, title, description, category, difficulty, xp_reward, flag_hash) VALUES
 (1, 'Membangun Landing Page Responsif', 'Layout flex/grid dengan Tailwind CSS.', 'coding', 'easy',   50,  NULL),
 (1, 'CRUD Sederhana dengan PHP & MySQL', 'Operasi Create-Read-Update-Delete.',    'coding', 'medium', 100, NULL),
 (2, 'SQL Injection Dasar (Sandbox)',     'Temukan flag pada aplikasi rentan buatan.', 'ctf', 'easy',  75,  SHA2('CLUBHUB{sqli_basic}', 256)),
 (3, 'Wireframe Dashboard LMS',           'Rancang low-fidelity wireframe.',     'design', 'easy',   50,  NULL),
 (4, 'Konfigurasi VLAN Dasar',            'Simulasi switch dan segmentasi jaringan.', 'network', 'medium', 100, NULL),
 (5, 'Sensor Ultrasonik & Servo',         'Penghindar rintangan berbasis Arduino.', 'iot', 'medium', 100, NULL);

INSERT INTO submissions (user_id, module_id, code_content, flag_submitted, status, score) VALUES
 (3, 3, NULL, 'CLUBHUB{sqli_basic}', 'accepted', 100),
 (4, 1, '<!doctype html><html>...</html>', NULL, 'pending', 0);

INSERT INTO ai_chat_logs (user_id, module_id, prompt, ai_response) VALUES
 (3, 3, 'Bagaimana cara mengetahui parameter yang rentan?',
        'Coba amati bagaimana input memengaruhi respons server. Apa yang terjadi jika Anda menambahkan tanda kutip tunggal?');

-- Contoh kueri leaderboard
-- SELECT * FROM v_leaderboard ORDER BY peringkat LIMIT 10;
