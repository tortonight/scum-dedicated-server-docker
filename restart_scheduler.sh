#!/bin/bash

# ============================================
# SCUM Server Restart Scheduler
# รีสตาร์ทเกมตามเวลาที่กำหนด (RESTART_SCHEDULE)
# เช่น RESTART_SCHEDULE=4,10,16,22
# ============================================

# ตั้งค่า Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[SCHEDULER]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warn()  { echo -e "${YELLOW}[SCHEDULER]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# อ่าน RESTART_SCHEDULE (ค่าเริ่มต้น: 4,10,16,22)
RESTART_SCHEDULE=${RESTART_SCHEDULE:-"4,10,16,22"}

# แปลงเป็น Array (รองรับ , หรือ space)
IFS=',' read -ra SCHEDULE_HOURS <<< "$RESTART_SCHEDULE"

# Trim whitespace
for i in "${!SCHEDULE_HOURS[@]}"; do
    SCHEDULE_HOURS[$i]=$(echo "${SCHEDULE_HOURS[$i]}" | tr -d ' ')
done

log_info "Restart Scheduler เริ่มทำงาน"
log_info "เวลารีสตาร์ท: ${SCHEDULE_HOURS[*]} นาฬิกา"

# ฟังก์ชัน: รีสตาร์ทเฉพาะเกม (ไม่ใช่ Container)
restart_game_only() {
    log_warn "===== ถึงเวลารีสตาร์ท SCUM Server ตามตาราง ====="
    
    # ซิงค์ Save Game ก่อน
    log_info "กำลังซิงค์ Save Game..."
    SAVE_SRC="/scum/SCUM/Saved/SaveGames"
    SAVE_DST="/scum_saved"
    if [ -d "$SAVE_SRC" ]; then
        cp -rf "$SAVE_SRC/"* "$SAVE_DST/" 2>/dev/null || true
        log_info "ซิงค์ Save Game สำเร็จ"
    fi
    
    # หยุด SCUM Server
    log_warn "กำลังหยุด SCUM Server..."
    SCUM_PIDS=$(pgrep -f "SCUMServer-Win64-Shipping" 2>/dev/null || true)
    
    if [ -n "$SCUM_PIDS" ]; then
        # ส่ง SIGTERM (shutdown อย่างนิ่มนวล)
        echo "$SCUM_PIDS" | while read pid; do
            kill -TERM $pid 2>/dev/null || true
        done
        
        # รอ 30 วินาที
        for i in $(seq 1 30); do
            if ! pgrep -f "SCUMServer-Win64-Shipping" > /dev/null 2>&1; then
                log_info "SCUM Server หยุดแล้ว (ใช้เวลา ${i} วินาที)"
                break
            fi
            sleep 1
        done
        
        # ถ้ายังไม่ตาย ส่ง SIGKILL
        SCUM_PIDS=$(pgrep -f "SCUMServer-Win64-Shipping" 2>/dev/null || true)
        if [ -n "$SCUM_PIDS" ]; then
            log_warn "SCUM Server ยังไม่หยุด ส่ง SIGKILL..."
            echo "$SCUM_PIDS" | while read pid; do
                kill -KILL $pid 2>/dev/null || true
            done
            sleep 5
        fi
    else
        log_warn "ไม่พบ SCUM Server ที่กำลังทำงาน"
    fi
    
    # รอเล็กน้อยก่อนเริ่มใหม่
    sleep 10
    
    # เริม SCUM Server ใหม่
    log_info "กำลังเริ่ม SCUM Server ใหม่..."
    GAMEPORT=${GAMEPORT:-7777}
    QUERYPORT=${QUERYPORT:-27015}
    MAXPLAYERS=${MAXPLAYERS:-64}
    ADDITIONALFLAGS=${ADDITIONALFLAGS:-}
    PROTON_DIR="/home/scum/.steam/root/compatibilitytools.d/GE-Proton9-20"
    GAME_DIR="/scum"
    STEAM_APP_ID="1881410"
    
    export SteamAppId=$STEAM_APP_ID
    export SteamGameId=$STEAM_APP_ID
    export WINEPREFIX="/home/scum/.wine"
    export WINEARCH="win64"
    
    cd "$GAME_DIR"
    xvfb-run -a $PROTON_DIR/files/bin/wine64 SCUM/Binaries/Win64/SCUMServer-Win64-Shipping.exe \
        -log \
        -port=$GAMEPORT \
        -queryport=$QUERYPORT \
        -MaxPlayers=$MAXPLAYERS \
        $ADDITIONALFLAGS &
    
    NEW_PID=$!
    log_info "SCUM Server เริ่มทำงานใหม่แล้ว (PID: ${NEW_PID})"
    log_warn "===== รีสตาร์ทเสร็จสิ้น ====="
}

# ฟังก์ชัน: ตรวจสอบว่าชั่วโมงปัจจุบันอยู่ในตารางหรือไม่
is_scheduled_hour() {
    CURRENT_HOUR=$(date +%H)
    # ตัด leading zero
    CURRENT_HOUR=$((10#$CURRENT_HOUR))
    
    for hour in "${SCHEDULE_HOURS[@]}"; do
        if [ "$hour" -eq "$CURRENT_HOUR" ]; then
            return 0
        fi
    done
    return 1
}

# ===== Main Loop =====
LAST_RESTART_DAY=""
LAST_RESTART_HOUR=""

log_info "รอเวลารีสตาร์ทครั้งถัดไป..."

while true; do
    CURRENT_HOUR=$(date +%H)
    CURRENT_MINUTE=$(date +%M)
    CURRENT_DAY=$(date +%d)
    
    # ตรวจสอบว่าถึงเวลารีสตาร์ทหรือยัง
    # รีสตาร์ทที่นาที 0 ของชั่วโมงที่กำหนด
    if [ "$CURRENT_MINUTE" = "00" ] || [ "$CURRENT_MINUTE" = "01" ] || [ "$CURRENT_MINUTE" = "02" ]; then
        if is_scheduled_hour; then
            # ป้องกันรีสตาร์ทซ้ำในชั่วโมงเดียวกัน
            if [ "$LAST_RESTART_DAY" != "$CURRENT_DAY" ] || [ "$LAST_RESTART_HOUR" != "$CURRENT_HOUR" ]; then
                # ตรวจสอบว่า SCUM Server กำลังทำงานอยู่
                if pgrep -f "SCUMServer-Win64-Shipping" > /dev/null 2>&1; then
                    log_info "ถึงเวลารีสตาร์ท: $(date '+%Y-%m-%d %H:%M:%S')"
                    restart_game_only
                    LAST_RESTART_DAY=$CURRENT_DAY
                    LAST_RESTART_HOUR=$CURRENT_HOUR
                    
                    # รอ 5 นาทีเพื่อไม่ให้เช็คซ้ำ
                    sleep 300
                else
                    log_warn "SCUM Server ไม่ได้ทำงาน ข้ามการรีสตาร์ท"
                fi
            fi
        fi
    fi
    
    # รอ 30 วินาที ก่อนตรวจสอบใหม่
    sleep 30
done