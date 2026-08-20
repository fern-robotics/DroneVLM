# DroneVLM: Cosys-AirSim on RunPod
> DroneVLM is built on Cosys-AirSim, an MIT-licensed fork and extension of Microsoft AirSim maintained by Cosys Lab, University of Antwerp. DroneVLM contributes a model-agnostic VLM adapter and ROS 2 semantic UAV-navigation experiment pipeline.

## Deploy

Apply the Fern patch in the Fern checkout, build it, then deploy:

```bash
cd /path/to/fern
git apply /path/to/DroneVLM/patches/fern-cosys-airsim-vnc.patch
cargo build --release
FERN_BIN="$PWD/target/release/fern" /path/to/DroneVLM/scripts/deploy-with-fern.sh
```

The profile exposes noVNC at:

```text
https://<pod-id>-6901.proxy.runpod.net/vnc.html?autoconnect=true&resize=remote
```

## Configure the Pod

Copy this repository to `/workspace/DroneVLM`, then run as root:

```bash
export VNC_PASSWORD='<6-to-8-character-password>'
/workspace/DroneVLM/scripts/bootstrap-vnc.sh
cp /workspace/DroneVLM/settings/multirotor.json /home/airsim/Documents/AirSim/settings.json
/workspace/DroneVLM/scripts/setup-ros2-humble.sh
install -m 0755 /workspace/DroneVLM/scripts/ros2-humble /usr/local/bin/ros2-humble
/workspace/DroneVLM/scripts/start-ros2.sh
```

Run the mission as the `airsim` user:

```bash
runuser -u airsim -- env HOME=/home/airsim bash -c '
  source /opt/ros/humble/setup.bash
  source /workspace/Cosys-AirSim-src/ros2/install/setup.bash
  /workspace/DroneVLM/scripts/ros2_waypoint_mission.py
'
```
