#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  Rover Setup — Full Provisioning"
echo "  Target: Raspberry Pi 4/5 (ARM64)"
echo "  ROS2: Lyrical | OS: Ubuntu Noble"
echo "============================================"
echo ""

# Must run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root. Use: sudo bash setup.sh"
    exit 1
fi

echo "[1/4] Installing ROS2..."
bash "$SCRIPT_DIR/scripts/ros2_setup.sh"

echo ""
echo "[2/4] Installing rover core service & workspace..."
bash "$SCRIPT_DIR/scripts/install_rover_service.sh"

echo ""
echo "[3/4] Setting up camera driver & node..."
bash "$SCRIPT_DIR/scripts/setup_camera.sh"

echo ""
echo "[4/4] Setting up teleop controller..."
bash "$SCRIPT_DIR/scripts/setup_controller.sh"

echo ""
echo "============================================"
echo "  Rover setup complete!"
echo ""
echo "  Services installed:"
echo "    - rover-node.service  (core ROS2 host node)"
echo "    - camera-node.service (camera image publisher)"
echo "    - joy-node.service    (joystick driver)"
echo "    - teleop.service       (teleop twist node)"
echo ""
echo "  Reboot to start all services:"
echo "    sudo reboot"
echo "============================================"
