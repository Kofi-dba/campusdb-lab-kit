-- =====================================================================
-- w1_samples.sql  -  ready-made sample databases for WEEK 1 (labs 2-5)
-- Week 1 is about understanding, not building, so labctl loads these
-- for you. In week 2 you build CampusDB yourself.
--
--   sheet_demo      : student records stored "like a spreadsheet"
--                     (one big flat table, everything is text)
--   campus_preview  : the same information stored the relational way
--                     (separate tables joined by keys)
--
-- Library analogy: sheet_demo is a messy pile of photocopied notes;
-- campus_preview is a proper card catalogue.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. sheet_demo : the "shared Excel file"
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS sheet_demo;
CREATE DATABASE sheet_demo;
USE sheet_demo;

-- Every column is free text, exactly like a spreadsheet cell.
-- No primary key, no rules: anyone can type anything anywhere.
CREATE TABLE results_sheet (
  row_no        INT,
  student_name  VARCHAR(60),
  phone         VARCHAR(20),
  programme     VARCHAR(40),
  course        VARCHAR(10),
  score         VARCHAR(10),
  fees_paid_ghs VARCHAR(12),
  lecturer      VARCHAR(40)
);

INSERT INTO results_sheet VALUES
  (1, 'Ama Mensah',    '0244 123 456', 'BSc IT', 'DBA401', '78',      '4500', 'Dr Asante'),
  (2, 'Ama Mensah',    '0244 123 456', 'BSc IT', 'NET402', '81',      '4500', 'Mrs Owusu'),
  (3, 'Ama Mensah',    '0201 555 777', 'BSc IT', 'SWE403', '69',      '4500', 'Mr Tetteh'),
  (4, 'Kwame Boateng', '0277 888 999', 'BSc CS', 'DBA401', '65',      '2250', 'Dr Asante'),
  (5, 'K. Boateng',    '0277 888 999', 'BSc CS', 'NET402', 'seventy', '2250', 'Mrs Owusu'),
  (6, 'Efua Owusu',    '0233 444 222', 'BSc IT', 'NET402', '82',      '0',    'Mrs Owusu'),
  (7, 'Efua Owusu',    '0233 444 222', 'B.Sc IT','DBA401', '',        '0',    'Dr. Asante'),
  (8, 'Yaw Asante',    '0266 101 202', 'BSc CS', 'DBA401', '71',      '4,500','Dr Asante'),
  (8, 'Yaw Asante',    '0266 101 202', 'BSc CS', 'SWE403', '59',      '4,500','Mr Tetteh');

-- ---------------------------------------------------------------------
-- 2. campus_preview : the same facts, stored the relational way
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS campus_preview;
CREATE DATABASE campus_preview;
USE campus_preview;

CREATE TABLE students (
  student_id  INT PRIMARY KEY,          -- the unique barcode on each card
  first_name  VARCHAR(50) NOT NULL,
  last_name   VARCHAR(50) NOT NULL,
  phone       VARCHAR(20),
  programme   VARCHAR(50)
);

CREATE TABLE courses (
  course_code VARCHAR(10) PRIMARY KEY,
  title       VARCHAR(100) NOT NULL,
  lecturer    VARCHAR(50)
);

CREATE TABLE enrolments (
  enrol_id    INT AUTO_INCREMENT PRIMARY KEY,
  student_id  INT NOT NULL,             -- points at students.student_id
  course_code VARCHAR(10) NOT NULL,     -- points at courses.course_code
  semester    VARCHAR(10) NOT NULL,
  score       INT CHECK (score BETWEEN 0 AND 100),
  FOREIGN KEY (student_id)  REFERENCES students(student_id),
  FOREIGN KEY (course_code) REFERENCES courses(course_code)
);

INSERT INTO students VALUES
  (10452, 'Ama',   'Mensah',  '0201 555 777', 'BSc IT'),
  (10453, 'Kwame', 'Boateng', '0277 888 999', 'BSc CS'),
  (10454, 'Efua',  'Owusu',   '0233 444 222', 'BSc IT'),
  (10455, 'Yaw',   'Asante',  '0266 101 202', 'BSc CS');

INSERT INTO courses VALUES
  ('DBA401', 'Database Administration', 'Dr Asante'),
  ('NET402', 'Network Security',        'Mrs Owusu'),
  ('SWE403', 'Software Engineering',    'Mr Tetteh');

INSERT INTO enrolments (student_id, course_code, semester, score) VALUES
  (10452, 'DBA401', '2026-1', 78),
  (10452, 'NET402', '2026-1', 81),
  (10452, 'SWE403', '2026-1', 69),
  (10453, 'DBA401', '2026-1', 65),
  (10453, 'NET402', '2026-1', 70),
  (10454, 'NET402', '2026-1', 82),
  (10454, 'DBA401', '2026-1', NULL),
  (10455, 'DBA401', '2026-1', 71),
  (10455, 'SWE403', '2026-1', 59);
