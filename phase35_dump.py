import sqlite3
import os
import sys
import shutil
import subprocess

"""
Tool hỗ trợ sao lưu / tạo / dump file cơ sở dữ liệu SQLite binary (.db) cho dự án Flutter (sqflite).
Cú pháp:
  1. Dump file .db nguồn ra file .db sao lưu:
     python phase35_dump.py copy input.db output.db

  2. Tạo/Chuyển đổi từ script SQL thành file binary .db:
     python phase35_dump.py sql2db dump.sql output.db

  3. Kéo file .db từ Android Emulator (ADB) về máy:
     python phase35_dump.py adb [com.example.app] [target.db]
"""

def copy_db(src_db, dst_db):
    if not os.path.exists(src_db):
        print(f"[-] File DB nguồn không tồn tại: {src_db}")
        return False
    shutil.copy2(src_db, dst_db)
    print(f"[+] Đã sao lưu thành công file SQLite binary (.db): {dst_db}")
    return True

def sql_to_db(sql_file, db_out):
    if not os.path.exists(sql_file):
        print(f"[-] File SQL không tồn tại: {sql_file}")
        return False
    if os.path.exists(db_out):
        os.remove(db_out)
    
    conn = sqlite3.connect(db_out)
    cursor = conn.cursor()
    with open(sql_file, 'r', encoding='utf-8') as f:
        sql_script = f.read()
    cursor.executescript(sql_script)
    conn.commit()
    conn.close()
    print(f"[+] Đã khởi tạo thành công cơ sở dữ liệu SQLite binary (.db): {db_out}")
    return True

def pull_adb_db(pkg_name="com.example.demo", out_db="schedify_uid0.db"):
    # Đường dẫn ứng dụng Flutter mặc định trên Android
    remote_path = f"/data/data/{pkg_name}/databases/{out_db}"
    print(f"[+] Đang kéo file .db từ Android Emulator: {remote_path} -> {out_db}")
    res = subprocess.run(["adb", "pull", remote_path, out_db], capture_output=True, text=True)
    if res.returncode == 0:
        print(f"[+] Kéo file DB thành công: {out_db}")
    else:
        print(f"[-] Lỗi adb pull (Kiểm tra xem emulator/device có đang chạy không):\n{res.stderr}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Cách sử dụng:")
        print("  python phase35_dump.py copy <input.db> <output.db>")
        print("  python phase35_dump.py sql2db <script.sql> <output.db>")
        print("  python phase35_dump.py adb [package_name] [db_name]")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "copy" and len(sys.argv) >= 4:
        copy_db(sys.argv[2], sys.argv[3])
    elif cmd == "sql2db" and len(sys.argv) >= 4:
        sql_to_db(sys.argv[2], sys.argv[3])
    elif cmd == "adb":
        pkg = sys.argv[2] if len(sys.argv) > 2 else "com.example.demo"
        dbname = sys.argv[3] if len(sys.argv) > 3 else "schedify_uid0.db"
        pull_adb_db(pkg, dbname)
    else:
        # Mặc định: Nếu truyền 2 tham số file db thì copy
        if len(sys.argv) == 3:
            copy_db(sys.argv[1], sys.argv[2])
        else:
            print("Tham số không hợp lệ.")
