#!/bin/bash
set -e

# ============================================
# SCUM Dedicated Server Docker - Entrypoint
# ใช้ Proton GE + SteamCMD
# ============================================

# ตั้งค่า Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${GREEN}[INFO]${NC}  $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# ===== ตั้งค่า Environment Variables =====
GAMEPORT=${GAMEPORT:-7777}
QUERYPORT=${QUERYPORT:-27015}
MAXPLAYERS=${MAXPLAYERS:-64}
ADDITIONALFLAGS=${ADDITIONALFLAGS:-}
MEMORY_THRESHOLD_PERCENT=${MEMORY_THRESHOLD_PERCENT:-95}
MEMORY_CHECK_INTERVAL=${MEMORY_CHECK_INTERVAL:-60}
GAME_UPDATE=${GAME_UPDATE:-false}
RESTART_SCHEDULE=${RESTART_SCHEDULE:-"4,10,16,22"}

# SteamCMD App ID สำหรับ SCUM Dedicated Server
STEAM_APP_ID="1881410"

# Path ต่างๆ
STEAMCMD_DIR="/home/scum/steamcmd"
GAME_DIR="/scum"
SAVE_DIR="/scum_saved"
PROTON_DIR="/home/scum/.steam/root/compatibilitytools.d/GE-Proton9-20"

log_info "========================================="
log_info "SCUM Dedicated Server Docker Container"
log_info "========================================="
log_info "Game Port:    ${GAMEPORT}"
log_info "Query Port:   ${QUERYPORT}"
log_info "Max Players:  ${MAXPLAYERS}"
log_info "Auto Update:  ${GAME_UPDATE}"
log_info "Memory Limit: ${MEMORY_THRESHOLD_PERCENT}%"
log_info "Restart At:   ${RESTART_SCHEDULE}"
log_info "========================================="

# ===== ฟังก์ชัน: ติดตั้ง/อัปเดต SCUM Server =====
install_or_update_server() {
    log_info "กำลังตรวจสอบ SCUM Dedicated Server..."
    
    if [ "$GAME_UPDATE" = "true" ] || [ ! -f "$GAME_DIR/SCUM.exe" ]; then
        log_info "กำลังดาวน์โหลด/อัปเดตผ่าน SteamCMD..."
        
        cat > /tmp/steam_update.txt << EOF
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir $GAME_DIR
login anonymous
app_update $STEAM_APP_ID validate
quit
EOF
        
        $STEAMCMD_DIR/steamcmd.sh +runscript /tmp/steam_update.txt
        
        if [ $? -eq 0 ]; then
            log_info "ติดตั้ง/อัปเดต SCUM Server สำเร็จ"
        else
            log_error "ไม่สามารถติดตั้ง/อัปเดต SCUM Server ได้"
            exit 1
        fi
    else
        log_info "GAME_UPDATE=false ข้ามการอัปเดต"
    fi
}

# ===== ฟังก์ชัน: เริ่ม SCUM Server =====
start_scum_server() {
    log_info "กำลังเริ่ม SCUM Dedicated Server..."
    log_info "ใช้ Proton GE จาก: ${PROTON_DIR}"
    
    # สร้างไฟล์ตั้งค่า Server
    cat > "$GAME_DIR/SCUM/Saved/Config/WindowsServer/ServerSettings.ini" << EOF
[ServerSettings]
MaxAllowedPlayers=$MAXPLAYERS
ServerPassword=
AdminPassword=admin
ServerName=SCUM Dedicated Server
ServerPort=$GAMEPORT
QueryPort=$QUERYPORT
$ADDITIONALFLAGS
EOF
    
    # กำหนด Steam App ID สำหรับ Proton
    export SteamAppId=$STEAM_APP_ID
    export SteamGameId=$STEAM_APP_ID
    
    # กำหนด Wine/Proton Prefix
    export WINEPREFIX="/home/scum/.wine"
    export WINEARCH="win64"
    
    # ถ้าไม่มี wine prefix ให้สร้างใหม่
    if [ ! -d "$WINEPREFIX" ]; then
        log_info "กำลังสร้าง Wine Prefix..."
        $PROTON_DIR/files/bin/wine64 wineboot -u
    fi
    
    # รัน SCUM Server ด้วย Proton/Wine
    log_info "เริ่ม SCUM.exe..."
    cd "$GAME_DIR"
    
    # ใช้ xvfb สำหรับ headless (ไม่มี display)
    xvfb-run -a $PROTON_DIR/files/bin/wine64 SCUM/Binaries/Win64/SCUMServer-Win64-Shipping.exe \
        -log \
        -port=$GAMEPORT \
        -queryport=$QUERYPORT \
        -MaxPlayers=$MAXPLAYERS \
        $ADDITIONALFLAGS &
    
    SCUM_PID=$!
    log_info "SCUM Server เริ่มทำงานแล้ว (PID: ${SCUM_PID})"
    
    # รอให้ Server พร้อม
    sleep 10
}

# ===== ฟังก์ชัน: หยุด SCUM Server =====
stop_scum_server() {
    log_warn "กำลังหยุด SCUM Server..."
    
    # ค้นหา PID ของ SCUM server
    SCUM_PIDS=$(pgrep -f "SCUMServer-Win64-Shipping" 2>/dev/null || true)
    
    if [ -n "$SCUM_PIDS" ]; then
        # ส่ง SIGTERM ก่อน
        echo "$SCUM_PIDS" | while read pid; do
            kill -TERM $pid 2>/dev/null || true
        done
        
        # รอ 30 วิ
        sleep 30
        
        # ถ้ายังไม่ตาย ส่ง SIGKILL
        SCUM_PIDS=$(pgrep -f "SCUMServer-Win64-Shipping" 2>/dev/null || true)
        if [ -n "$SCUM_PIDS" ]; then
            echo "$SCUM_PIDS" | while read pid; do
                kill -KILL $pid 2>/dev/null || true
            done
            log_info "SCUM Server ถูกบังคับหยุดแล้ว"
        else
            log_info "SCUM Server หยุดแล้ว"
        fi
    else
        log_warn "ไม่พบ SCUM Server ที่กำลังทำงาน"
    fi
    
    sleep 5
}

# ===== ฟังก์ชัน: ซิงค์ Save Games =====
sync_saves() {
    log_info "กำลังซิงค์ไฟล์ Save Game..."
    
    SAVE_SRC="$GAME_DIR/SCUM/Saved/SaveGames"
    SAVE_DST="$SAVE_DIR"
    
    if [ -d "$SAVE_SRC" ]; then
        # Copy ไปยัง external volume
        cp -rf "$SAVE_SRC/"* "$SAVE_DST/" 2>/dev/null || true
        log_info "ซิงค์ save game ไปยัง $SAVE_DST สำเร็จ"
    else
        log_warn "ไม่พบโฟลเดอร์ SaveGame: $SAVE_SRC"
    fi
}

# ===== ฟังก์ชัน: Restore Save Games =====
restore_saves() {
    log_info "กำลังกู้คืน Save Game..."
    
    SAVE_SRC="$SAVE_DIR"
    SAVE_DST="$GAME_DIR/SCUM/Saved/SaveGames"
    
    if [ -d "$SAVE_SRC" ] && [ "$(ls -A $SAVE_SRC 2>/dev/null)" ]; then
        mkdir -p "$SAVE_DST"
        cp -rf "$SAVE_SRC/"* "$SAVE_DST/" 2>/dev/null || true
        log_info "กู้คืน save game จาก $SAVE_SRC สำเร็จ"
    else
        log_warn "ไม่พบ save game ใน $SAVE_SRC หรือโฟลเดอร์ว่าง"
    fi
}

# ===== ฟังก์ชัน: Restart Server =====
restart_server() {
    log_info "======== รีสตาร์ท SCUM Server ========"
    sync_saves
    stop_scum_server
    start_scum_server
    log_info "======== รีสตาร์ทเสร็จสิ้น ========"
}

# ===== Signal Handler =====
cleanup() {
    log_warn "ได้รับสัญญาณหยุดการทำงาน..."
    sync_saves
    stop_scum_server
    log_info "Container หยุดทำงานแล้ว"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# ===== Main =====
main() {
    # ติดตั้ง/อัปเดตเซิร์ฟเวอร์
    install_or_update_server
    
    # Restore save games
    restore_saves
    
    # เริ่ม SCUM Server
    start_scum_server
    
    # เริ่ม Memory Monitor ใน background
    if [ -f "/home/scum/memory_monitor.sh" ]; then
        log_info "เริ่ม Memory Monitor..."
        bash /home/scum/memory_monitor.sh &
    fi
    
    # เริ่ม Restart Scheduler ใน background
    if [ -f "/home/scum/restart_scheduler.sh" ]; then
        log_info "เริ่ม Restart Scheduler..."
        bash /home/scum/restart_scheduler.sh &
    fi
    
    # จัดการ Save Game ทุก 5 นาที
    while true; do
        sleep 300
        sync_saves
    done
}

# เริ่ม Main
main