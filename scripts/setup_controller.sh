#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ROS2_WS="/home/rover/ros2_ws"
UDEV_RULE="/etc/udev/rules.d/99-ps4-controller.rules"

echo "=== Setting up Bluetooth teleop controller ==="

# --- Install Bluetooth stack ---
echo "Installing Bluetooth stack..."
apt update
apt install -y bluez bluetooth python3-pip

# Enable and start Bluetooth
systemctl enable bluetooth
systemctl start bluetooth 2>/dev/null || true

# --- Install ROS2 teleop + joy packages ---
echo "Installing ROS2 teleop and joy packages..."
apt install -y ros-lyrical-joy ros-lyrical-teleop-twist-joy ros-lyrical-teleop-twist-keyboard

# --- Install ds4drv for PS4/PS5 controller ---
echo "Installing ds4drv for PS4/PS5 controller support..."
pip3 install ds4drv --break-system-packages || true

# --- udev rule for controller input access ---
echo "Setting up udev rule for controller access..."
cat > "$UDEV_RULE" <<'UDEV'
# PS4 / PS5 DualShock / DualSense controller — grant rover user access
SUBSYSTEM=="input", ATTRS{name}=="*Wireless Controller*", MODE="0666", GROUP="rover"
SUBSYSTEM=="input", ATTRS{name}=="*DualSense*", MODE="0666", GROUP="rover"
SUBSYSTEM=="input", ATTRS{name}=="*DualShock*", MODE="0666", GROUP="rover"
UDEV

udevadm control --reload-rules
udevadm trigger

# --- Copy teleop config ---
echo "Installing teleop configuration..."
mkdir -p /home/rover/.ros
cp "$SCRIPT_DIR/../configs/teleop_configs.yaml" /home/rover/.ros/teleop_configs.yaml
chown -R rover:rover /home/rover/.ros

# --- Install teleop systemd service ---
echo "Installing teleop systemd service..."
cp "$SCRIPT_DIR/../etc/systemd/teleop.service" /etc/systemd/system/teleop.service
chmod 644 /etc/systemd/system/teleop.service

# --- Install joy-node systemd service ---
echo "Installing joy-node systemd service..."
cp "$SCRIPT_DIR/../etc/systemd/joy-node.service" /etc/systemd/system/joy-node.service
chmod 644 /etc/systemd/system/joy-node.service

systemctl daemon-reload
systemctl enable teleop.service
systemctl enable joy-node.service

echo "Teleop controller setup complete."
echo "Pair your PS4/PS5 controller with: bluetoothctl"
echo "Then reboot or start the service: systemctl start teleop.service"
