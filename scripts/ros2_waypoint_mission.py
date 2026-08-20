#!/usr/bin/python3.10
"""Run a bounded ROS 2 multirotor out-and-back mission, then land safely."""
import time

import rclpy
from airsim_interfaces.msg import VelCmd
from airsim_interfaces.srv import Land, Takeoff
from rclpy.node import Node

VEHICLE = "drone_1"


class VelocityMission(Node):
    def __init__(self):
        super().__init__("cosys_velocity_mission")
        self.velocity = self.create_publisher(
            VelCmd, f"/airsim_node/{VEHICLE}/vel_cmd_world_frame", 10
        )

    def call(self, client, request):
        if not client.wait_for_service(timeout_sec=30.0):
            raise RuntimeError(f"service unavailable: {client.srv_name}")
        future = client.call_async(request)
        rclpy.spin_until_future_complete(self, future, timeout_sec=30.0)
        if future.result() is None:
            raise RuntimeError(f"service call failed: {client.srv_name}")

    def command_for(self, x, y, z, seconds):
        message = VelCmd()
        message.twist.linear.x = x
        message.twist.linear.y = y
        message.twist.linear.z = z
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            self.velocity.publish(message)
            rclpy.spin_once(self, timeout_sec=0.0)
            time.sleep(0.1)

    def stop(self):
        self.command_for(0.0, 0.0, 0.0, 1.0)


def main():
    rclpy.init()
    node = VelocityMission()
    try:
        takeoff = node.create_client(Takeoff, f"/airsim_node/{VEHICLE}/takeoff")
        land = node.create_client(Land, f"/airsim_node/{VEHICLE}/land")
        # Cosys-AirSim 5.8 executes these tasks but leaves Response.success false.
        node.call(takeoff, Takeoff.Request(wait_on_last_task=True))
        node.command_for(0.25, 0.0, 0.0, 4.0)   # forward 1 m
        node.command_for(-0.25, 0.0, 0.0, 4.0)  # return home
        node.stop()
        node.call(land, Land.Request(wait_on_last_task=True))
    finally:
        node.stop()
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
