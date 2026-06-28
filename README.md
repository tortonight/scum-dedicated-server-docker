# 🎮 SCUM Dedicated Server Docker Image

![SCUM](https://img.shields.io/badge/SCUM-Dedicated%20Server-orange)
![Docker](https://img.shields.io/badge/Docker-Ready-blue)
![Linux](https://img.shields.io/badge/Linux-Supported-green)
![Proton GE](https://img.shields.io/badge/Proton-GE-red)

## 📋 ภาพรวม

Docker Image สำหรับรัน **SCUM Dedicated Server** บน Linux โดยใช้ **Proton GE** (GloriousEggroll) และ **SteamCMD** ให้ประสิทธิภาพสูงกว่า Wine ทั่วไป

### ✨ ฟีเจอร์หลัก

- 🚀 **ติดตั้งอัตโนมัติ** - ดาวน์โหลดและติดตั้ง SCUM Server ผ่าน SteamCMD
- 🔄 **อัปเดตง่าย** - รองรับการอัปเดตอัตโนมัติ (เปิด/ปิดได้)
- 💾 **Persistent Save Game** - ข้อมูล Save Game ถูกจัดเก็บแยก Volume ไม่สูญหาย
- 🕐 **รีสตาร์ทตามเวลา** - รีสตาร์ทเฉพาะเกมตามเวลาที่กำหนด (ทุก 6 ชม. ตามค่าเริ่มต้น)
- 📊 **Memory Monitor** - ตรวจสอบการใช้ Memory และรีสตาร์ทอัตโนมัติเมื่อเกินเกณฑ์
- ⚡ **Proton GE** - ใช้ Proton GE แทน Wine เพื่อประสิทธิภาพที่ดีขึ้น
- 🔒 **ปลอดภัย** - รันด้วย User แยก ไม่ใช้ Root

---

## 🏗️ โครงสร้างไฟล์

```
SCUM Dedicated Server Docker Image/
├── Dockerfile              # สร้าง Docker Image
├── docker-compose.yml      # ตั้งค่า Container
├── entrypoint.sh           # สคริปต์เริ่มทำงานหลัก
├── memory_monitor.sh       # ตรวจสอบ Memory
├── restart_scheduler.sh    # รีสตาร์ทตามเวลา
├── .env.example            # ตัวอย่างไฟล์ตั้งค่า
└── README.md               # ไฟล์นี้
```

---

## 📦 ความต้องการ

- **Docker** 20.10+
- **Docker Compose** v3.8+
- **พื้นที่ดิสก์** อย่างน้อย 50GB (สำหรับเกมและ Save)
- **RAM** อย่างน้อย 8GB (แนะนำ 16GB+)
- **CPU** 4 Cores+

---

## 🚀 การติดตั้งและการใช้งาน

### 1. ดาวน์โหลดไฟล์ docker-compose.yml

```bash
git clone <repository-url> scum-docker
cd scum-docker
```

### 2. ตั้งค่า Environment (ไม่จำเป็น)

```bash
cp .env.example .env
nano .env  # แก้ไขค่าตามต้องการ
```

### 3. Pull Image จาก Docker Hub และรัน Container

```bash
# ดึง Image ล่าสุดจาก Docker Hub
docker-compose pull

# รัน Container
docker-compose up -d

# ดู Logs
docker-compose logs -f
```

> **หมายเหตุ:** ใช้ Image จาก Docker Hub `tonight01gamer/scum-dedicated-server:latest` โดยตรง ไม่ต้อง build เอง

### 4. หยุด Container

```bash
docker-compose down
```

---

## ⚙️ การตั้งค่า Environment Variables

| ตัวแปร | ค่าเริ่มต้น | คำอธิบาย |
|--------|-------------|----------|
| `GAMEPORT` | `7777` | พอร์ตหลักของเกม |
| `QUERYPORT` | `27015` | พอร์ตสำหรับ Server Query (ใช้ตรวจสอบสถานะ) |
| `MAXPLAYERS` | `64` | จำนวนผู้เล่นสูงสุด |
| `ADDITIONALFLAGS` | `""` | แฟล็กเพิ่มเติมสำหรับเซิร์ฟเวอร์ |
| `GAME_UPDATE` | `false` | เปิด/ปิด การอัปเดตอัตโนมัติเมื่อเริ่ม Container (`true`/`false`) |
| `MEMORY_THRESHOLD_PERCENT` | `95` | เกณฑ์การใช้ Memory (%) ที่จะรีสตาร์ท |
| `MEMORY_CHECK_INTERVAL` | `60` | ระยะเวลากວດสอบ Memory (วินาที) |
| `RESTART_SCHEDULE` | `4,10,16,22` | เวลารีสตาร์ทเซิร์ฟเวอร์ (นาฬิกา, คั่นด้วยลูกน้ำ) เช่น `0,6,12,18` = รีสตาร์ทที่ 00:00, 06:00, 12:00, 18:00 |

### ตัวอย่างการเปลี่ยนการตั้งค่า

```yaml
# docker-compose.yml
environment:
  - GAMEPORT=7777
  - QUERYPORT=27015
  - MAXPLAYERS=50
  - GAME_UPDATE=true
  - MEMORY_THRESHOLD_PERCENT=90
  - MEMORY_CHECK_INTERVAL=30
  - RESTART_SCHEDULE=0,6,12,18
```

---

## 📂 Volumes (การจัดเก็บข้อมูล)

| Path (Host) | Path (Container) | คำอธิบาย |
|-------------|------------------|----------|
| `/srv/games/scum/game` | `/scum` | ไฟล์เกมและไบนารี |
| `/srv/games/scum/saves` | `/scum_saved` | ไฟล์ Save Game |
| `/srv/games/scum/steam_data` | `/home/scum/.steam` | ข้อมูล Steam |

### หมายเหตุด้านความปลอดภัย

- ✅ Save Game จะถูกบันทึกแยกใน Volume `/srv/games/scum/saves`
- ✅ จะไม่มีทางสูญหายแม้ Container ถูกลบ
- ✅ มีการ Sync Save Game ทุก 5 นาที

---

## 🔄 ระบบรีสตาร์ทอัตโนมัติ

### 1. รีสตาร์ทตามเวลา (RESTART_SCHEDULE)

ตามค่าเริ่มต้นจะรีสตาร์ทเฉพาะเกม (ไม่ใช่ Container) ที่:

```
04:00, 10:00, 16:00, 22:00 นาฬิกา
```

**ปรับแต่งได้:**
```bash
# รีสตาร์ททุก 6 ชั่วโมง
RESTART_SCHEDULE=0,6,12,18

# รีสตาร์ทวันละ 2 ครั้ง
RESTART_SCHEDULE=3,15

# รีสตาร์ทเฉพาะตอนตี 4
RESTART_SCHEDULE=4
```

### 2. รีสตาร์ทเมื่อ Memory สูง (Memory Monitor)

ถ้าการใช้ Memory เกินเกณฑ์ที่ตั้งไว้ (ค่าเริ่มต้น 95%) ติดต่อกัน 2 ครั้ง จะรีสตาร์ทเกมอัตโนมัติ:

- `MEMORY_THRESHOLD_PERCENT=95` - เกณฑ์ (%)
- `MEMORY_CHECK_INTERVAL=60` - ตรวจสอบทุกกี่วินาที

---

## 🎮 การตั้งค่าเกม

หลังจากรัน Container ครั้งแรก จะมีการสร้างไฟล์ `ServerSettings.ini` อัตโนมัติ:

```
/scum/SCUM/Saved/Config/WindowsServer/ServerSettings.ini
```

**การตั้งค่าพื้นฐานที่กำหนดอัตโนมัติ:**
- Max Players
- Server Port
- Query Port
- Admin Password (ค่าเริ่มต้น: `admin`)

### การแก้ไขการตั้งค่าเพิ่มเติม

สามารถใช้ `ADDITIONALFLAGS` เพื่อส่งค่าเพิ่ม:

```bash
ADDITIONALFLAGS=-ServerName=MyServer -AdminPassword=password123
```

หรือเข้าไปแก้ไฟล์ `ServerSettings.ini` ใน Container โดยตรง

---

## 🌐 Ports (พอร์ตที่ใช้)

| Port | Protocol | คำอธิบาย |
|------|----------|----------|
| 7777 | UDP | พอร์ตหลักของเกม |
| 7777 | TCP | การเชื่อมต่อ TCP |
| 7778 | UDP | Game Port + 1 |
| 27015 | UDP | Server Query Port |

**ตรวจสอบว่า Firewall เปิดพอร์ตเหล่านี้แล้ว**

---

## 📊 Health Check

Container มี Health Check ในตัว ตรวจสอบว่า SCUM Server ทำงานอยู่หรือไม่ทุก 30 วินาที:

```yaml
healthcheck:
  test: ["CMD", "pgrep", "-f", "SCUM.exe"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 120s
```

---

## 🛠️ การแก้ไขปัญหา

### ปัญหาทั่วไป

1. **Container เริ่มไม่ได้**
   ```bash
   docker-compose logs  # ดู logs
   ```

2. **SteamCMD ดาวน์โหลดไม่ได้**
   - ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
   - ตรวจสอบ Firewall

3. **เกมไม่เริ่ม**
   - ตรวจสอบ Memory ว่าเพียงพอหรือไม่
   - ตรวจสอบ Proton GE ว่าติดตั้งถูกต้อง `ls /home/scum/.steam/root/compatibilitytools.d/`

4. **พอร์ตไม่เปิด**
   ```bash
   netstat -tulpn | grep -E '7777|27015'
   ```

### คำสั่งที่มีประโยชน์

```bash
# เข้า Container
docker exec -it scum-dedicated-server bash

# ดูการใช้ทรัพยากร
docker stats scum-dedicated-server

# ดูเฉพาะกระบวนการ SCUM
docker exec scum-dedicated-server pgrep -f SCUM

# รีสตาร์ท Container
docker-compose restart

# ลบและสร้างใหม่ทั้งหมด
docker-compose down -v
docker-compose pull
docker-compose up -d
```

---

## 🐳 Docker Hub

Image พร้อมใช้งานบน Docker Hub:

| Registry | Image |
|----------|-------|
| **Docker Hub** | `tonight01gamer/scum-dedicated-server:latest` |

```bash
# Pull Image โดยตรง
docker pull tonight01gamer/scum-dedicated-server:latest

# หรือใช้ docker-compose
docker-compose pull
```

## 🔧 การ Customize

### เปลี่ยนเวลารีสตาร์ท

แก้ไขใน `.env` หรือ `docker-compose.yml`:

```bash
RESTART_SCHEDULE=0,4,8,12,16,20  # ทุก 4 ชั่วโมง
```

---

## 📈 Performance Tips

1. **เพิ่ม RAM** - SCUM Server ใช้ RAM ค่อนข้างมาก
2. **ใช้ SSD** - สำหรับ Volume ที่เก็บเกม
3. **ปรับ Memory Threshold** - ลดลงเหลือ 80-85% สำหรับเซิร์ฟเวอร์ที่มี RAM จำกัด
4. **ตั้งเวลารีสตาร์ทนอกช่วงผู้เล่นเยอะ** - เพื่อไม่รบกวนผู้เล่น

---

## 📝 License

MIT License

---

## 🤝 การมีส่วนร่วม

พบปัญหาหรือต้องการแนะนำ? กรุณาเปิด Issue หรือ Pull Request

---

## 📞 การติดต่อ

- GitHub Issues: [เปิด Issue](https://github.com/your-repo/issues)
- Discord: [SCUM Thailand Community](https://discord.gg/scum-th)

---

> **หมายเหตุ:** SCUM เป็นเครื่องหมายการค้าของ Gamepires และ Devolver Digital โครงการนี้เป็นเพียงเครื่องมือช่วยติดตั้งและจัดการเซิร์ฟเวอร์เท่านั้น