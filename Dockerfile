FROM ubuntu:22.04

# ตั้งค่า Non-Interactive สำหรับ apt-get
ENV DEBIAN_FRONTEND=noninteractive

# ติดตั้ง Dependencies ที่จำเป็น
RUN apt-get update && apt-get install -y \
    lib32gcc-s1 \
    lib32stdc++6 \
    curl \
    wget \
    tar \
    xvfb \
    procps \
    net-tools \
    ca-certificates \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# สร้าง User สำหรับรันเซิร์ฟเวอร์
RUN useradd -m -d /home/scum -s /bin/bash scum

# สร้าง Directory สำหรับ SteamCMD
RUN mkdir -p /home/scum/steamcmd

WORKDIR /home/scum/steamcmd

# ติดตั้ง SteamCMD
RUN curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# ติดตั้ง Proton GE (GloriousEggroll build)
# ดาวน์โหลด Proton GE Release ล่าสุด
RUN mkdir -p /home/scum/.steam/root/compatibilitytools.d && \
    wget -q --show-progress "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-20/GE-Proton9-20.tar.gz" -O /tmp/proton-ge.tar.gz && \
    tar -xzf /tmp/proton-ge.tar.gz -C /home/scum/.steam/root/compatibilitytools.d/ && \
    rm /tmp/proton-ge.tar.gz

# ตั้งค่า Steam สำหรับใช้ Proton
RUN mkdir -p /home/scum/.steam/steam/steamapps && \
    echo "Proton GE Ready" > /home/scum/.steam/root/compatibilitytools.d/proton_version.txt

# สร้าง Directory สำหรับเกมและ saves
RUN mkdir -p /scum /scum_saved /home/scum/.steam/sdk64

# Copy สคริปต์ทั้งหมด
COPY --chown=scum:scum entrypoint.sh /home/scum/entrypoint.sh
COPY --chown=scum:scum memory_monitor.sh /home/scum/memory_monitor.sh
COPY --chown=scum:scum restart_scheduler.sh /home/scum/restart_scheduler.sh

# ตั้งค่าสิทธิ์การ execute
RUN chmod +x /home/scum/entrypoint.sh \
    /home/scum/memory_monitor.sh \
    /home/scum/restart_scheduler.sh

# เปลี่ยนเจ้าของไฟล์
RUN chown -R scum:scum /scum /scum_saved /home/scum

# ตั้งค่า Volume
VOLUME ["/scum", "/scum_saved", "/home/scum/.steam"]

# เริ่มด้วย User scum (ไม่ใช้ root)
USER scum
WORKDIR /home/scum

# Entrypoint
ENTRYPOINT ["/home/scum/entrypoint.sh"]