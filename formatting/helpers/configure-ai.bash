#!/usr/bin/env bash
function helptext {
    echo "Usage: configure-ai.bash"
    echo
    echo 'This script configures Ubuntu Server for AI inference on a Framework Desktop.'
}
set -e
USER='admin'

echo ':: Setting up audio codecs...'
apt install -y sox ffmpeg

echo ':: Setting up Python...'
apt install -y python3-venv python3-pip

echo ':: Setting up OCR...'
apt install -y tesseract-ocr

echo ':: Adjusting limits...'
cat > /etc/sysctl.d/99-ai.conf <<'EOL'
vm.max_map_count = 1048576
EOL
sysctl --system

echo ':: Setting up Docker...'
apt install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker "$USER"

echo ':: Setting up ROCm...'
apt install -y wget gnupg2 ca-certificates
wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor | tee /usr/share/keyrings/rocm.gpg > /dev/null
ROCM_VERSION=6.0
DISTRO=$(lsb_release -cs)
apt-mark hold linux-image-generic linux-headers-generic
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION}/ ${DISTRO} main" > /etc/apt/sources.list.d/rocm.list
apt update
apt install -y rocm-core rocm-hip-runtime rocm-opencl-runtime rocminfo
usermod -aG video,render $USER

echo ':: Testing ROCm...'
docker run --rm -it \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
  rocm/rocm-terminal \
  rocminfo

echo ':: Setting up directories...'
mkdir -p /srv/models

## Done
echo ':: Done.'
exit 0
