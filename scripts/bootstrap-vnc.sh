#!/usr/bin/env bash
# Run this once on the Fern-created RunPod as root.
set -Eeuo pipefail

: "${VNC_PASSWORD:?Set VNC_PASSWORD to an 8-character VNC password before running this script}"
if ((${#VNC_PASSWORD} < 6 || ${#VNC_PASSWORD} > 8)); then
  echo "VNC_PASSWORD must contain 6 to 8 characters (TigerVNC's VNC authentication limit)." >&2
  exit 2
fi

readonly RELEASE="5.8-v3.4.1"
readonly ASSET="Blocks_packaged_Linux_58_341.zip"
readonly DOWNLOAD_URL="https://github.com/Cosys-Lab/Cosys-AirSim/releases/download/${RELEASE}/${ASSET}"
readonly INSTALL_DIR="/workspace/cosys-airsim"
readonly LOG_DIR="${INSTALL_DIR}/logs"
readonly DISPLAY_NUM=1
readonly AIRSIM_USER=airsim
readonly AIRSIM_HOME="/home/${AIRSIM_USER}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates dbus-x11 libasound2 libglu1-mesa libnss3 libvulkan1 \
  libxcursor1 libxi6 libxinerama1 libxrandr2 libxss1 libxtst6 \
  novnc tigervnc-standalone-server tigervnc-tools unzip vulkan-tools websockify wget xfce4

if ! id -u "${AIRSIM_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${AIRSIM_USER}"
fi
usermod -aG audio,video "${AIRSIM_USER}"
mkdir -p "${INSTALL_DIR}" "${LOG_DIR}" "${AIRSIM_HOME}/.vnc" "${AIRSIM_HOME}/Documents/AirSim"
if [[ ! -f "${INSTALL_DIR}/.${RELEASE}-installed" ]]; then
  tmp_zip="$(mktemp --suffix=.zip)"
  wget --progress=dot:giga -O "${tmp_zip}" "${DOWNLOAD_URL}"
  unzip -q "${tmp_zip}" -d "${INSTALL_DIR}"
  rm -f "${tmp_zip}"
  touch "${INSTALL_DIR}/.${RELEASE}-installed"
fi

# The packaged Blocks build reads this optional AirSim settings file at startup.
cat > "${AIRSIM_HOME}/Documents/AirSim/settings.json" <<'EOF'
{
  "SettingsVersion": 2.0,
  "SimMode": "Multirotor",
  "RpcEnabled": true,
  "ApiServerPort": 41451,
  "ViewMode": "FlyWithMe",
  "EngineSound": false,
  "Vehicles": {
    "drone_1": {
      "VehicleType": "SimpleFlight",
      "DefaultVehicleState": "Armed",
      "AutoCreate": true,
      "AllowAPIAlways": true,
      "RC": {"RemoteControlID": -1, "AllowAPIWhenDisconnected": true}
    }
  }
}
EOF

chown -R "${AIRSIM_USER}:${AIRSIM_USER}" "${INSTALL_DIR}" "${AIRSIM_HOME}"
printf '%s\n%s\n' "${VNC_PASSWORD}" "${VNC_PASSWORD}" |
  runuser -u "${AIRSIM_USER}" -- tigervncpasswd "${AIRSIM_HOME}/.vnc/passwd"
chmod 600 "${AIRSIM_HOME}/.vnc/passwd"
cat > "${AIRSIM_HOME}/.vnc/xstartup" <<'EOF'
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
EOF
chmod 700 "${AIRSIM_HOME}/.vnc/xstartup"
chown -R "${AIRSIM_USER}:${AIRSIM_USER}" "${AIRSIM_HOME}"

# Restart the desktop, web client, and simulator if the bootstrap is re-run.
runuser -u "${AIRSIM_USER}" -- env HOME="${AIRSIM_HOME}" vncserver -kill ":${DISPLAY_NUM}" >/dev/null 2>&1 || true
pkill -f "Xtigervnc :${DISPLAY_NUM}" >/dev/null 2>&1 || true
pkill -f "websockify.*6901" >/dev/null 2>&1 || true
pkill -f '/Blocks.*-windowed' >/dev/null 2>&1 || true

runuser -u "${AIRSIM_USER}" -- env HOME="${AIRSIM_HOME}" \
  vncserver ":${DISPLAY_NUM}" -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes VncAuth
nohup websockify --web=/usr/share/novnc 6901 "localhost:$((5900 + DISPLAY_NUM))" \
  >"${LOG_DIR}/novnc.log" 2>&1 &

blocks_sh="$(find "${INSTALL_DIR}" -type f -name Blocks.sh -print -quit)"
if [[ -z "${blocks_sh}" ]]; then
  echo "Blocks.sh was not found after extracting ${ASSET}." >&2
  exit 1
fi
chmod +x "${blocks_sh}"
blocks_dir="$(dirname "${blocks_sh}")"
(
  cd "${blocks_dir}"
  export DISPLAY=":${DISPLAY_NUM}"
  export SDL_VIDEODRIVER=x11
  export NVIDIA_DRIVER_CAPABILITIES=all
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  exec runuser -u "${AIRSIM_USER}" -- env HOME="${AIRSIM_HOME}" DISPLAY="${DISPLAY}" \
    SDL_VIDEODRIVER="${SDL_VIDEODRIVER}" NVIDIA_DRIVER_CAPABILITIES="${NVIDIA_DRIVER_CAPABILITIES}" \
    __GLX_VENDOR_LIBRARY_NAME="${__GLX_VENDOR_LIBRARY_NAME}" \
    "${blocks_sh}" -windowed -ResX=1920 -ResY=1080 -ForceRes -vulkan
) >"${LOG_DIR}/blocks.log" 2>&1 &

echo "Cosys-AirSim is starting. Logs: ${LOG_DIR}/blocks.log and ${LOG_DIR}/novnc.log"
