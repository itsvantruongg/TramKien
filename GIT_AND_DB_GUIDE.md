## 🗄️ QUẢN LÝ & SAO LƯU CƠ SỞ DỮ LIỆU SQLITE (`phase35_dump.py`)

Script `phase35_dump.py` hỗ trợ thao tác trực tiếp với file SQLite binary (`.db`) cho dự án:

### Các lệnh phổ biến:

1. **Sao lưu (Copy) file `.db` nội bộ**:
   ```bash
   python phase35_dump.py copy schedify_uid0.db my_backup.db
   ```

2. **Kéo file `.db` trực tiếp từ Android Emulator về máy**:
   ```bash
   python phase35_dump.py adb com.example.demo schedify_uid0.db
   ```

3. **Tạo file cơ sở dữ liệu `.db` từ file kịch bản SQL**:
   ```bash
   python phase35_dump.py sql2db dump_script.sql my_database.db
   ```

---
