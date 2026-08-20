#!/usr/bin/env bash
# Build the Cosys-AirSim 5.8-v3.4.1 ROS 2 bridge on Ubuntu 22.04.
# Run as root after scripts/bootstrap-vnc.sh has created the airsim user.
set -Eeuo pipefail

readonly SOURCE_DIR=/workspace/Cosys-AirSim-src
readonly TAG=5.8-v3.4.1
readonly AIRSIM_USER=airsim
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg sudo build-essential cmake clang libc++-dev libc++abi-dev \
  libyaml-cpp-dev libpcl-dev rsync
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key |
  gpg --dearmor --yes -o /etc/apt/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" \
  >/etc/apt/sources.list.d/ros2.list
apt-get update
apt-get install -y --no-install-recommends \
  ros-humble-ros-base ros-humble-cv-bridge ros-humble-geographic-msgs \
  ros-humble-image-transport ros-humble-mavros-msgs ros-humble-pcl-conversions \
  ros-humble-tf2-geometry-msgs ros-humble-tf2-sensor-msgs \
  python3-colcon-common-extensions

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  git clone --depth 1 --branch "${TAG}" https://github.com/Cosys-Lab/Cosys-AirSim.git "${SOURCE_DIR}"
fi
cd "${SOURCE_DIR}"
./setup.sh --no-full-poly-car

# Humble's cv_bridge uses cv_bridge.h; this Cosys release targets newer ROS 2.
sed -i 's|<cv_bridge/cv_bridge.hpp>|<cv_bridge/cv_bridge.h>|' \
  ros2/src/airsim_ros_pkgs/include/airsim_ros_wrapper.h
# The upstream PD node subscribes to an odom_local_ned topic that this release does not publish.
sed -i 's|/odom_local_ned|/odom_local|' \
  ros2/src/airsim_ros_pkgs/src/pd_position_controller_simple.cpp
chown -R "${AIRSIM_USER}:${AIRSIM_USER}" "${SOURCE_DIR}"

runuser -u "${AIRSIM_USER}" -- env HOME="/home/${AIRSIM_USER}" bash -c '
  source /opt/ros/humble/setup.bash
  cd /workspace/Cosys-AirSim-src
  /usr/bin/python3.10 /usr/bin/colcon --log-base ros2/log build \
    --base-paths ros2 --build-base ros2/build --install-base ros2/install \
    --cmake-args -DCMAKE_BUILD_TYPE=Release \
      -DPython3_EXECUTABLE=/usr/bin/python3.10 -DPYTHON_EXECUTABLE=/usr/bin/python3.10
'
