#!/usr/bin/python3.10
"""Fly a square mission through Cosys-AirSim's ROS 2 PD controller."""
import rclpy
from rclpy.node import Node
from airsim_interfaces.srv import Land, SetLocalPosition, Takeoff

import math
import time

from nav_msgs.msg import Odometry

VEHICLE = "drone_1"
# A 1 m square relative to the post-takeoff pose; altitude is held constant.
SQUARE_OFFSETS = [(1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.0, 0.0)]


class WaypointMission(Node):
    def __init__(self):
        super().__init__("cosys_waypoint_mission")
        self.position = None
        self.create_subscription(Odometry, f"/airsim_node/{VEHICLE}/odom_local", self.odom, 10)

    def odom(self, message):
        self.position = message.pose.pose.position

    def call(self, client, request):
        if not client.wait_for_service(timeout_sec=30.0):
            raise RuntimeError(f"service unavailable: {client.srv_name}")
        future = client.call_async(request)
        rclpy.spin_until_future_complete(self, future, timeout_sec=30.0)
        if future.result() is None:
            raise RuntimeError(f"service call failed: {client.srv_name}")
        return future.result()

    def wait_for_odom(self):
        deadline = time.monotonic() + 30.0
        while time.monotonic() < deadline:
            rclpy.spin_once(self, timeout_sec=0.1)
            if self.position is not None:
                return
        raise RuntimeError("timed out waiting for drone odometry")

    def wait_for_waypoint(self, x, y, z):
        deadline = time.monotonic() + 60.0
        while time.monotonic() < deadline:
            rclpy.spin_once(self, timeout_sec=0.1)
            if self.position is not None and math.dist(
                (self.position.x, self.position.y, self.position.z), (x, y, z)
            ) < 0.35:
                return
        raise RuntimeError(f"timed out reaching {(x, y, z)}")


def main():
    rclpy.init()
    node = WaypointMission()
    try:
        takeoff = node.create_client(Takeoff, f"/airsim_node/{VEHICLE}/takeoff")
        goal = node.create_client(SetLocalPosition, "/airsim_node/local_position_goal")
        land = node.create_client(Land, f"/airsim_node/{VEHICLE}/land")

        # The upstream wrapper performs the task but leaves its success field unset.
        node.call(takeoff, Takeoff.Request(wait_on_last_task=True))
        node.wait_for_odom()
        home = (node.position.x, node.position.y, node.position.z)
        for dx, dy in SQUARE_OFFSETS:
            x, y, z = home[0] + dx, home[1] + dy, home[2]
            request = SetLocalPosition.Request()
            request.x, request.y, request.z, request.yaw = x, y, z, 0.0
            request.vehicle_name = VEHICLE
            node.call(goal, request)
            node.wait_for_waypoint(x, y, z)
        node.call(land, Land.Request(wait_on_last_task=True))
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
