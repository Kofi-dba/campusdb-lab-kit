-- =====================================================================
-- 01_campusdb.sql  -  CampusDB as it should look at the END of Lab 2
-- Four tables (students, courses, enrolments, fees) with keys,
-- constraints and sample data. Safe to re-run: it rebuilds from scratch.
--
-- Library analogy: this script builds the Science wing (database),
-- fits four shelves (tables) and files the first catalogue cards (rows).
-- =====================================================================

DROP DATABASE IF EXISTS campusdb;
CREATE DATABASE campusdb CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE campusdb;

CREATE TABLE students (
  student_id  INT PRIMARY KEY,
  first_name  VARCHAR(50)  NOT NULL,
  last_name   VARCHAR(50)  NOT NULL,
  email       VARCHAR(100) UNIQUE,
  programme   VARCHAR(50),
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE courses (
  course_code VARCHAR(10) PRIMARY KEY,
  title       VARCHAR(100) NOT NULL,
  credits     INT CHECK (credits BETWEEN 1 AND 6)
);

CREATE TABLE enrolments (
  enrol_id    INT AUTO_INCREMENT PRIMARY KEY,
  student_id  INT NOT NULL,
  course_code VARCHAR(10) NOT NULL,
  score       INT CHECK (score BETWEEN 0 AND 100),
  FOREIGN KEY (student_id)  REFERENCES students(student_id),
  FOREIGN KEY (course_code) REFERENCES courses(course_code)
);

CREATE TABLE fees (
  payment_id  INT AUTO_INCREMENT PRIMARY KEY,
  student_id  INT NOT NULL,
  amount_ghs  DECIMAL(10,2) NOT NULL,
  paid_on     DATE NOT NULL,
  FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- ---------------------------------------------------------------------
-- Sample data (same as the syllabus, plus a few extra rows so queries
-- and JOINs have something interesting to show)
-- ---------------------------------------------------------------------
INSERT INTO students (student_id, first_name, last_name, email, programme) VALUES
  (10452,'Ama','Mensah','ama.m@campus.edu.gh','BSc IT'),
  (10453,'Kwame','Boateng','kwame.b@campus.edu.gh','BSc CS'),
  (10454,'Efua','Owusu','efua.o@campus.edu.gh','BSc IT'),
  (10455,'Yaw','Asante','yaw.a@campus.edu.gh','BSc CS'),
  (10456,'Akosua','Darko','akosua.d@campus.edu.gh','BSc IT'),
  (10457,'Kojo','Appiah','kojo.a@campus.edu.gh','BSc Information Systems');

INSERT INTO courses VALUES
  ('DBA401','Database Administration',3),
  ('NET402','Network Security',3),
  ('SWE403','Software Engineering',3);

INSERT INTO enrolments (student_id, course_code, score) VALUES
  (10452,'DBA401',78),(10453,'DBA401',65),(10454,'NET402',82),
  (10455,'DBA401',71),(10455,'SWE403',59),(10456,'NET402',88),
  (10457,'SWE403',74);

INSERT INTO fees (student_id, amount_ghs, paid_on) VALUES
  (10452,4500.00,'2026-09-01'),
  (10453,2250.00,'2026-09-03'),
  (10455,4500.00,'2026-09-05'),
  (10456,1500.00,'2026-09-10');
