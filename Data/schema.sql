-- ============================================================
--  DATABASE TUYỂN SINH ĐẠI HỌC VIỆT NAM
--  PostgreSQL Schema - Phiên bản có khả năng mở rộng
--  Tạo từ: Bang1 (trường), Bang2 (ngành), Bang3 (phương thức),
--           Bang4 (chỉ tiêu), Bang5 (điểm chuẩn)
-- ============================================================

-- Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- BẢNG 1: universities - Trường đại học
-- Nguồn: Bang1.csv
-- ============================================================
CREATE TABLE universities (
    university_code     VARCHAR(10)  PRIMARY KEY,
    university_name     VARCHAR(255) NOT NULL,
    location            VARCHAR(100),
    region              VARCHAR(50),        -- Miền: Bắc / Trung / Nam (tự sinh)
    description         TEXT,
    university_type     VARCHAR(50),        -- Mở rộng: Công lập / Tư thục / Quốc tế
    website             VARCHAR(255),
    logo_url            TEXT,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE universities IS 'Danh sách trường đại học - nguồn Bang1.csv';
COMMENT ON COLUMN universities.region IS 'Tự sinh từ location: Bắc / Trung / Nam';

-- ============================================================
-- BẢNG 2: majors - Ngành học theo trường
-- Nguồn: Bang2.csv
-- ============================================================
CREATE TABLE majors (
    id                  SERIAL PRIMARY KEY,
    major_code          VARCHAR(20)  NOT NULL,
    university_code     VARCHAR(10)  NOT NULL REFERENCES universities(university_code),
    major_name          VARCHAR(255) NOT NULL,
    introduction        TEXT,
    degree_level        VARCHAR(20)  DEFAULT 'Đại học',  -- Mở rộng: CĐ / ĐH / Thạc sĩ
    duration_years      SMALLINT     DEFAULT 4,
    tuition_fee         NUMERIC(15,0),                   -- Mở rộng: học phí
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (major_code, university_code)
);

COMMENT ON TABLE majors IS 'Ngành học theo từng trường - nguồn Bang2.csv';

-- ============================================================
-- BẢNG 3: admission_methods - Phương thức xét tuyển
-- Nguồn: Bang3.csv
-- ============================================================
CREATE TABLE admission_methods (
    method_code         INTEGER      PRIMARY KEY,
    method_name         VARCHAR(255) NOT NULL,
    method_group        VARCHAR(100),    -- Nhóm: Thi THPT / Học bạ / ĐGNL / Khác
    description         TEXT,
    is_active           BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE admission_methods IS 'Phương thức xét tuyển - nguồn Bang3.csv';

-- ============================================================
-- BẢNG 4: admission_quotas - Chỉ tiêu tuyển sinh
-- Nguồn: Bang4.csv
-- ============================================================
CREATE TABLE admission_quotas (
    id                  SERIAL PRIMARY KEY,
    year                SMALLINT    NOT NULL,
    university_code     VARCHAR(10) NOT NULL REFERENCES universities(university_code),
    major_code          VARCHAR(20) NOT NULL,
    method_code         INTEGER     NOT NULL REFERENCES admission_methods(method_code),
    quota               INTEGER,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (year, university_code, major_code, method_code),
    FOREIGN KEY (major_code, university_code) REFERENCES majors(major_code, university_code)
);

COMMENT ON TABLE admission_quotas IS 'Chỉ tiêu tuyển sinh theo năm - nguồn Bang4.csv';

-- ============================================================
-- BẢNG 5: passing_scores - Điểm chuẩn
-- Nguồn: Bang5final.csv
-- ============================================================
CREATE TABLE passing_scores (
    id                  SERIAL PRIMARY KEY,
    year                SMALLINT    NOT NULL,
    university_code     VARCHAR(10) NOT NULL REFERENCES universities(university_code),
    major_code          VARCHAR(20) NOT NULL,
    major_name_detail   VARCHAR(255),   -- Tên ngành chi tiết (có thể khác major_name)
    method_code         INTEGER     NOT NULL REFERENCES admission_methods(method_code),
    subject_combinations VARCHAR(100),  -- VD: "A00; A01; D01"
    passing_score       NUMERIC(5,2),
    secondary_criteria  TEXT,           -- Tiêu chí phụ nếu bằng điểm
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (major_code, university_code) REFERENCES majors(major_code, university_code)
);

COMMENT ON TABLE passing_scores IS 'Điểm chuẩn các năm - nguồn Bang5final.csv';

-- ============================================================
-- BẢNG MỞ RỘNG: subject_groups - Tổ hợp môn thi
-- ============================================================
CREATE TABLE subject_groups (
    group_code          VARCHAR(5)   PRIMARY KEY,  -- A00, D01, ...
    group_name          VARCHAR(50),
    subjects            VARCHAR(150)                -- VD: Toán, Lý, Hóa
);

COMMENT ON TABLE subject_groups IS 'Danh mục tổ hợp môn thi - bảng mở rộng';

-- ============================================================
-- BẢNG MỞ RỘNG: user_profiles - Hồ sơ thí sinh (cho web tư vấn)
-- ============================================================
CREATE TABLE user_profiles (
    id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name           VARCHAR(100),
    email               VARCHAR(150) UNIQUE,
    phone               VARCHAR(20),
    graduation_year     SMALLINT,
    province            VARCHAR(100),
    math_score          NUMERIC(4,2),
    literature_score    NUMERIC(4,2),
    english_score       NUMERIC(4,2),
    science_scores      JSONB,          -- {ly, hoa, sinh, su, dia, gdcd}
    preferred_majors    TEXT[],         -- Danh sách ngành quan tâm
    preferred_locations TEXT[],         -- Khu vực ưu tiên
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE user_profiles IS 'Hồ sơ thí sinh dùng cho tư vấn - bảng mở rộng';

-- ============================================================
-- BẢNG MỞ RỘNG: saved_searches - Kết quả tư vấn đã lưu
-- ============================================================
CREATE TABLE saved_searches (
    id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID         REFERENCES user_profiles(id) ON DELETE CASCADE,
    session_id          VARCHAR(100),   -- Cho anonymous users
    search_params       JSONB,
    results             JSONB,
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES - Tối ưu truy vấn phổ biến
-- ============================================================
-- Tìm ngành theo trường
CREATE INDEX idx_majors_university ON majors(university_code);

-- Tra cứu điểm chuẩn theo năm + trường + ngành
CREATE INDEX idx_scores_lookup ON passing_scores(year, university_code, major_code);
CREATE INDEX idx_scores_year ON passing_scores(year);
CREATE INDEX idx_scores_score ON passing_scores(passing_score);

-- Chỉ tiêu theo năm
CREATE INDEX idx_quotas_year ON admission_quotas(year, university_code);

-- Tìm trường theo vị trí
CREATE INDEX idx_universities_location ON universities(location);
CREATE INDEX idx_universities_region ON universities(region);

-- Full-text search tiếng Việt
CREATE INDEX idx_universities_name_fts ON universities USING gin(to_tsvector('simple', university_name));
CREATE INDEX idx_majors_name_fts ON majors USING gin(to_tsvector('simple', major_name));

-- ============================================================
-- VIEW: v_admission_summary - View tổng hợp cho API
-- ============================================================
CREATE OR REPLACE VIEW v_admission_summary AS
SELECT
    ps.year,
    u.university_code,
    u.university_name,
    u.location,
    u.region,
    m.major_code,
    m.major_name,
    ps.major_name_detail,
    am.method_code,
    am.method_name,
    am.method_group,
    ps.subject_combinations,
    ps.passing_score,
    ps.secondary_criteria,
    aq.quota
FROM passing_scores ps
JOIN universities u ON ps.university_code = u.university_code
JOIN majors m ON (ps.major_code = m.major_code AND ps.university_code = m.university_code)
JOIN admission_methods am ON ps.method_code = am.method_code
LEFT JOIN admission_quotas aq ON (
    aq.university_code = ps.university_code
    AND aq.major_code = ps.major_code
    AND aq.method_code = ps.method_code
    AND aq.year = ps.year + 1  -- chỉ tiêu năm tiếp theo
);

COMMENT ON VIEW v_admission_summary IS 'View tổng hợp dùng cho API tư vấn tuyển sinh';

-- ============================================================
-- FUNCTION: find_matching_schools - Gợi ý trường theo điểm
-- ============================================================
CREATE OR REPLACE FUNCTION find_matching_schools(
    p_score          NUMERIC,
    p_subject_combo  VARCHAR DEFAULT NULL,
    p_location       VARCHAR DEFAULT NULL,
    p_year           SMALLINT DEFAULT 2025,
    p_margin         NUMERIC DEFAULT 2.0   -- điểm ± margin
)
RETURNS TABLE (
    university_name  VARCHAR,
    location         VARCHAR,
    major_name       VARCHAR,
    method_name      VARCHAR,
    passing_score    NUMERIC,
    score_gap        NUMERIC,
    chance           VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.university_name,
        u.location,
        ps.major_name_detail,
        am.method_name,
        ps.passing_score,
        ROUND(p_score - ps.passing_score, 2) AS score_gap,
        CASE
            WHEN p_score >= ps.passing_score + 1  THEN 'Cao'
            WHEN p_score >= ps.passing_score       THEN 'Trung bình'
            WHEN p_score >= ps.passing_score - 1   THEN 'Thấp'
            ELSE 'Rất thấp'
        END AS chance
    FROM passing_scores ps
    JOIN universities u ON ps.university_code = u.university_code
    JOIN admission_methods am ON ps.method_code = am.method_code
    WHERE ps.year = p_year
      AND ps.passing_score BETWEEN (p_score - p_margin) AND (p_score + p_margin)
      AND (p_subject_combo IS NULL OR ps.subject_combinations ILIKE '%' || p_subject_combo || '%')
      AND (p_location IS NULL OR u.location ILIKE '%' || p_location || '%')
    ORDER BY ps.passing_score DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_matching_schools IS 'Tìm trường phù hợp dựa trên điểm thi và bộ môn';
