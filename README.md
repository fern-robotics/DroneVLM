# DroneVLM: Cosys-AirSim on RunPod

Reproducible Fern deployment, noVNC workspace, and ROS 2 Humble mission setup for the upstream **Cosys-AirSim 5.8-v3.4.1** packaged Blocks environment.

## Contents

- `patches/fern-cosys-airsim-vnc.patch` — adds Fern's `cosys-airsim-vnc` profile: RTX 4090-first GPU fallback, 80 GB container disk, 50 GB `/workspace`, SSH, noVNC, VNC, and AirSim RPC ports.
- `scripts/deploy-with-fern.sh` — billable Fern deployment command.
- `scripts/bootstrap-vnc.sh` — downloads Blocks, creates the `airsim` desktop user, starts TigerVNC/noVNC, and launches the GPU-backed simulator.
- `settings/multirotor.json` — SimpleFlight `drone_1` multirotor configuration.
- `scripts/setup-ros2-humble.sh` — builds the matching Cosys-AirSim ROS 2 bridge and interfaces.
- `scripts/ros2-humble` — forces ROS 2 Humble to use Ubuntu 22.04's Python 3.10 (the RunPod image's default Python is 3.11).
- `scripts/start-ros2.sh` — launches the bridge with API control and a bounded PD controller.
- `scripts/ros2_waypoint_mission.py` — take off, execute a bounded 1 m out-and-back ROS 2 velocity mission, then land.

No API key, SSH key, Pod address, or VNC password is stored here.

## Attribution and licensing

DroneVLM is built on [Cosys-AirSim](https://github.com/Cosys-Lab/Cosys-AirSim), an MIT-licensed extension of Microsoft AirSim maintained by Cosys Lab, University of Antwerp. This repository contributes the DroneVLM experiment setup, ROS 2 integration scripts, and a model-agnostic VLM adapter; it does not claim affiliation with or endorsement by Cosys Lab, University of Antwerp, Microsoft, or Codex Laboratories.

If Cosys-AirSim source is forked, modified, or distributed with this work, retain its complete upstream `LICENSE` and copyright notices. This repository intentionally contains installation scripts and configuration only: do not commit or redistribute the packaged Blocks/Unreal binaries, Unreal Engine assets, API credentials, or model weights unless their separate terms expressly permit redistribution. Each VLM, dataset, and external API used in an experiment remains subject to its own license and terms.

Suggested academic attribution:

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
