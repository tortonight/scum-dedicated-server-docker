#!/bin/bash

# ============================================
# SCUM Server Memory Monitor
# ตรวจสอบการใช้ Memory และรีสตาร์ทเมื่อเกินเกณฑ์
# ============================================

# ตั้งค่า Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[MEM-MONITOR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warn()  { echo -e "${YELLOW}[MEM-MONITOR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo -e "${RED}[MEM-MONITOR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# อ่าน Environment Variables
MEMORY_THRESHOLD_PERCENT=${MEMORY_THRESHOLD_PERCENT:-95}
MEMORY_CHECK_INTERVAL=${MEMORY_CHECK_INTERVAL:-60}

log_info "Memory Monitor เริ่มทำงาน"
log_info "เกณฑ์: ${MEMORY_THRESHOLD_PERCENT}% | ตรวจสอบทุก: ${MEMORY_CHECK_INTERVAL} วินาที"

# ฟังก์ชัน: ตรวจสอบ Memory
check_memory() {
    # รับ Memory Total (KB)
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    
    # รับ Memory Available (KB)
    MEM_AVAILABLE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    if [ -z "$MEM_TOTAL" ] || [ -z "$MEM_AVAILABLE" ] || [ "$MEM_TOTAL" -eq 0 ]; then
        log_error "ไม่สามารถอ่านค่า Memory ได้"
        return 1
    fi
    
    # คำนวณ Memory Used (%)
    MEM_USED=$(( (MEM_TOTAL - MEM_AVAILABLE) * 100 / MEM_TOTAL ))
    
    echo "$MEM_USED"
}

# ฟังก์ชัน: ตรวจสอบ Memory ของ SCUM Process
check_scum_memory() {
    SCUM_PIDS=$(pgrep -f "SCUMServer-Win64-Shipping" 2>/dev/null || true)
    
    if [ -z "$SCUM_PIDS" ]; then
        log_warn "ไม่พบ Process SCUM Server"
        return 1
    fi
    
    TOTAL_RSS=0
    
    for pid in $SCUM_PIDS; do
        # รับ RSS (Resident Set Size) เป็น KB
        RSS=$(ps -o rss= -p $pid 2>/dev/null | head -1 | tr -d ' ')
        if [ -n "$RSS" ]; then
            TOTAL_RSS=$((TOTAL_RSS + RSS))
        fi
    done
    
    # แปลงเป็น MB
    TOTAL_MB=$((TOTAL_RSS / 1024))
    
    echo "$TOTAL_MB"
}

# ฟังก์ชัน: Restart SCUM Server
restart_game_server() {
    log_error "Memory เกินเกณฑ์ ${MEMORY_THRESHOLD_PERCENT}% กำลังรีสตาร์ท SCUM Server..."
    
    # หยุด SCUM Server
    SCUM_PIDS=$(pgrep -f "SCUMServer-Win64-Shipping" 2>/dev/null || true)
    if [ -n "$SCUM_PIDS" ]; then
        log_warn "กำลังหยุด SCUM Server..."
        
        # Save ก่อน
        log_info "กำลังซิงค์ Save Game ก่อนรีสตาร์ท..."
        SAVE_SRC="/scum/SCUM/Saved/SaveGames"
        SAVE_DST="/scum_saved"
        if [ -d "$SAVE_SRC" ]; then
            cp -rf "$SAVE_SRC/"* "$SAVE_DST/" 2>/dev/null || true
        fi
        
        # ส่ง SIGTERM
        echo "$SCUM_PIDS" | while read pid; do
            kill -TERM $pid 2>/dev/null || true
        done
        sleep 30
        
        # ถ้ายังไม่ตาย ส่ง SIGKILL
        SCUM_PIDS=$(pgrep -f "SCUMServer-Win64-Shipping" 2>/dev/null || true)
        if [ -n "$SCUM_PIDS" ]; then
            echo "$SCUM_PIDS" | while read pid; do
                kill -KILL $pid 2>/dev/null || true
            done
        fi
        sleep 10
    fi
    
    # เริ่มใหม่
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
    
    log_info "SCUM Server รีสตาร์ทแล้ว (PID: $!)"
    sleep 10
}

# ===== Main Loop =====
CONSECUTIVE_HIGH=0

while true; do
    # ตรวจสอบว่ามี SCUM Server ทำงานอยู่ไหม
    if ! pgrep -f "SCUMServer-Win64-Shipping" > /dev/null 2>&1; then
        log_warn "SCUM Server ไม่ได้ทำงาน..."
        sleep $MEMORY_CHECK_INTERVAL
        continue
    fi
    
    # ตรวจสอบ Memory
    MEM_USAGE=$(check_memory)
    SCUM_MEM=$(check_scum_memory)
    
    if [ -n "$MEM_USAGE" ]; then
        if [ -n "$SCUM_MEM" ]; then
            log_info "Memory โดยรวม: ${MEM_USAGE}% | SCUM Memory: ${SCUM_MEM}MB"
        else
            log_info "Memory โดยรวม: ${MEM_USAGE}%"
        fi
        
        # ตรวจสอบว่าเกินเกณฑ์หรือไม่
        if [ "$MEM_USAGE" -ge "$MEMORY_THRESHOLD_PERCENT" ]; then
            CONSECUTIVE_HIGH=$((CONSECUTIVE_HIGH + 1))
            log_warn "Memory เกินเกณฑ์! (${MEM_USAGE}% >= ${MEMORY_THRESHOLD_PERCENT}%) - ครั้งที่ ${CONSECUTIVE_HIGH}"
            
            # ถ้าเกิน 2 ครั้งติดกัน รีสตาร์ท
            if [ $CONSECUTIVE_HIGH -ge 2 ]; then
                restart_game_server
                CONSECUTIVE_HIGH=0
            fi
        else
            CONSECUTIVE_HIGH=0
        fi
    fi
    
    sleep $MEMORY_CHECK_INTERVAL
done