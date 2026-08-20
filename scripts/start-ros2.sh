#!/usr/bin/env bash
# Start the Cosys-AirSim ROS 2 bridge and its bounded PD controller.
set -Eeuo pipefail

readonly LOG_DIR=/workspace/cosys-airsim/logs
readonly ROS2=/usr/local/bin/ros2-humble
readonly AIRSIM_USER=airsim
mkdir -p "${LOG_DIR}"

# Bracketed patterns cannot match this shell's own command line.
pkill -u "${AIRSIM_USER}" -f '[a]irsim_node' || true
pkill -u "${AIRSIM_USER}" -f '[p]d_position_controller_simple_node' || true
pkill -u "${AIRSIM_USER}" -f '[r]os2 launch airsim_ros_pkgs' || true

nohup runuser -u "${AIRSIM_USER}" -- env HOME="/home/${AIRSIM_USER}" \
  "${ROS2}" launch airsim_ros_pkgs airsim_node.launch.py \
  enable_api_control:=True publish_clock:=True \
  >"${LOG_DIR}/airsim_ros2_node.log" 2>&1 &
sleep 5
nohup runuser -u "${AIRSIM_USER}" -- env HOME="/home/${AIRSIM_USER}" \
  "${ROS2}" run airsim_ros_pkgs pd_position_controller_simple_node --ros-args \
  -p update_control_every_n_sec:=0.01 \
  -p kp_x:=0.30 -p kp_y:=0.30 -p kp_z:=0.30 -p kp_yaw:=0.30 \
  -p kd_x:=0.05 -p kd_y:=0.05 -p kd_z:=0.05 -p kd_yaw:=0.05 \
  -p reached_thresh_xyz:=0.15 -p reached_yaw_degrees:=5.0 \
  -p max_vel_horz_abs:=0.30 -p max_vel_vert_abs:=0.30 -p max_yaw_rate_degree:=1.0 \
  >"${LOG_DIR}/airsim_ros2_pd.log" 2>&1 &
