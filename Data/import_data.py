"""
Import dữ liệu từ 5 file CSV vào PostgreSQL
Chạy: python import_data.py

Yêu cầu:
  pip install pandas psycopg2-binary python-dotenv
"""

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import re

# ─── Cấu hình kết nối ─────────────────────────────────────────
DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "database": "tuyen_sinh",
    "user":     "postgres",
    "password": "your_password",   # ← đổi lại
}

# ─── Đường dẫn file CSV ───────────────────────────────────────
CSV_FILES = {
    "bang1": "Bang1.csv",
    "bang2": "bang2.csv",
    "bang3": "bang3.csv",
    "bang4": "bang4.csv",
    "bang5": "bang5final.csv",
}

def normalize_location(loc: str) -> str:
    """Chuẩn hóa tên địa điểm (vd: 'HCM - Hồ Chí Minh' -> 'Hồ Chí Minh')"""
    if not isinstance(loc, str):
        return loc
    loc = loc.strip()
    if loc.startswith("HCM"):
        return "Hồ Chí Minh"
    return loc

def get_region(location: str) -> str:
    """Xác định miền từ tên địa điểm"""
    if not isinstance(location, str):
        return "Khác"
    BAC = ["Hà Nội", "Hải Phòng", "Thái Nguyên", "Bắc Ninh", "Hưng Yên",
           "Hải Dương", "Vĩnh Phúc", "Bắc Giang", "Nam Định", "Hà Nam",
           "Ninh Bình", "Thái Bình", "Hà Giang", "Tuyên Quang", "Phú Thọ",
           "Yên Bái", "Sơn La", "Lào Cai", "Điện Biên", "Lai Châu",
           "Hòa Bình", "Bắc Kạn", "Cao Bằng", "Lạng Sơn", "Quảng Ninh"]
    TRUNG = ["Huế", "Đà Nẵng", "Nghệ An", "Hà Tĩnh", "Quảng Bình",
             "Quảng Trị", "Quảng Nam", "Quảng Ngãi", "Bình Định",
             "Phú Yên", "Khánh Hòa", "Ninh Thuận", "Bình Thuận",
             "Đắk Lắk", "Gia Lai", "Kon Tum", "Lâm Đồng", "Đắk Nông"]
    for city in BAC:
        if city in location:
            return "Miền Bắc"
    for city in TRUNG:
        if city in location:
            return "Miền Trung"
    return "Miền Nam"

def get_method_group(method_code: int, method_name: str) -> str:
    """Phân nhóm phương thức xét tuyển"""
    if method_code == 100:
        return "Thi THPT"
    elif method_code == 200:
        return "Học bạ"
    elif method_code in (301,):
        return "Xét thẳng"
    elif method_code in (401, 402, 403, 416):
        return "Thi ĐGNL / ĐGTD"
    elif method_code in (405, 406, 407, 408, 409, 410):
        return "Kết hợp"
    elif method_code in (411, 415):
        return "Quốc tế"
    return "Khác"


def read_csv(path: str) -> pd.DataFrame:
    """Đọc CSV với encoding UTF-8-BOM và dấu phân cách ;"""
    return pd.read_csv(path, sep=";", encoding="utf-8-sig", dtype=str)


def import_bang1(cur, df: pd.DataFrame):
    print("  → Importing universities (Bang1)...")
    df["location"] = df["location"].apply(normalize_location)
    df["region"]   = df["location"].apply(get_region)
    rows = [
        (
            row["university_code"].strip(),
            row["university_name"].strip(),
            row.get("location", ""),
            row.get("region", ""),
            row.get("description", "") or None,
        )
        for _, row in df.iterrows()
    ]
    execute_values(cur, """
        INSERT INTO universities (university_code, university_name, location, region, description)
        VALUES %s
        ON CONFLICT (university_code) DO UPDATE SET
            university_name = EXCLUDED.university_name,
            location        = EXCLUDED.location,
            region          = EXCLUDED.region,
            description     = EXCLUDED.description,
            updated_at      = NOW()
    """, rows)
    print(f"     ✓ {len(rows)} trường")


def import_bang3(cur, df: pd.DataFrame):
    print("  → Importing admission_methods (Bang3)...")
    rows = [
        (
            int(row["method_code"]),
            row["method_name"].strip(),
            get_method_group(int(row["method_code"]), row["method_name"]),
        )
        for _, row in df.iterrows()
    ]
    execute_values(cur, """
        INSERT INTO admission_methods (method_code, method_name, method_group)
        VALUES %s
        ON CONFLICT (method_code) DO UPDATE SET
            method_name  = EXCLUDED.method_name,
            method_group = EXCLUDED.method_group
    """, rows)
    print(f"     ✓ {len(rows)} phương thức")


def import_bang2(cur, df: pd.DataFrame):
    print("  → Importing majors (Bang2)...")
    rows = []
    for _, row in df.iterrows():
        rows.append((
            row["major_code"].strip(),
            row["university_code"].strip(),
            row["major_name"].strip(),
            row.get("introduction", "") or None,
        ))
    execute_values(cur, """
        INSERT INTO majors (major_code, university_code, major_name, introduction)
        VALUES %s
        ON CONFLICT (major_code, university_code) DO UPDATE SET
            major_name   = EXCLUDED.major_name,
            introduction = EXCLUDED.introduction,
            updated_at   = NOW()
    """, rows)
    print(f"     ✓ {len(rows)} ngành")


def import_bang4(cur, df: pd.DataFrame):
    print("  → Importing admission_quotas (Bang4)...")
    rows = []
    for _, row in df.iterrows():
        quota = row.get("quota")
        rows.append((
            int(row["year"]),
            row["university_code"].strip(),
            row["major_code"].strip(),
            int(row["method_code"]),
            int(quota) if pd.notna(quota) and str(quota).strip() else None,
        ))
    execute_values(cur, """
        INSERT INTO admission_quotas (year, university_code, major_code, method_code, quota)
        VALUES %s
        ON CONFLICT (year, university_code, major_code, method_code) DO UPDATE SET
            quota = EXCLUDED.quota
    """, rows)
    print(f"     ✓ {len(rows)} bản ghi chỉ tiêu")


def import_bang5(cur, df: pd.DataFrame):
    print("  → Importing passing_scores (Bang5)...")
    rows = []
    for _, row in df.iterrows():
        score = row.get("passing_score")
        try:
            score = float(str(score).replace(",", ".")) if pd.notna(score) and str(score).strip() else None
        except ValueError:
            score = None
        # Clean subject_combinations
        subj = row.get("subject_combinations", "") or ""
        subj = subj.strip().strip('"')
        rows.append((
            int(row["year"]),
            row["university_code"].strip(),
            row["major_code"].strip(),
            row.get("major_name", "").strip() or None,
            int(row["method_code"]),
            subj or None,
            score,
            row.get("secondary_criteria", "") or None,
        ))
    execute_values(cur, """
        INSERT INTO passing_scores
            (year, university_code, major_code, major_name_detail,
             method_code, subject_combinations, passing_score, secondary_criteria)
        VALUES %s
    """, rows)
    print(f"     ✓ {len(rows)} bản ghi điểm chuẩn")


def main():
    print("🔌 Connecting to PostgreSQL...")
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False
    cur = conn.cursor()

    try:
        print("\n📥 Bắt đầu import dữ liệu...\n")

        bang1 = read_csv(CSV_FILES["bang1"])
        bang2 = read_csv(CSV_FILES["bang2"])
        bang3 = read_csv(CSV_FILES["bang3"])
        bang4 = read_csv(CSV_FILES["bang4"])
        bang5 = read_csv(CSV_FILES["bang5"])

        # Thứ tự import quan trọng (parent trước child)
        import_bang1(cur, bang1)   # universities
        import_bang3(cur, bang3)   # admission_methods
        import_bang2(cur, bang2)   # majors (FK → universities)
        import_bang4(cur, bang4)   # admission_quotas (FK → majors, methods)
        import_bang5(cur, bang5)   # passing_scores (FK → majors, methods)

        conn.commit()
        print("\n✅ Import hoàn tất!")

    except Exception as e:
        conn.rollback()
        print(f"\n❌ Lỗi: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
