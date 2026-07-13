#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_URL="https://github.com/fatherofcamels/Rover-Client"
ROS2_WS="/home/rover/ros2_ws"
SERVICE_SRC="$SCRIPT_DIR/../etc/systemd/rover-node.service"
SERVICE_DST="/etc/systemd/system/rover-node.service"

# --- Ensure rover has serial device access ---
usermod -a -G dialout rover 2>/dev/null || true

# --- Clone ROS2 packages ---
if [[ ! -d "$ROS2_WS/src" ]]; then
    echo "Creating ROS2 workspace"
    mkdir -p "$ROS2_WS/src"
    chown -R rover:rover "$ROS2_WS"
fi

if [[ ! -d "$ROS2_WS/src/.git" ]]; then
    echo "Cloning Rover-Client repository"
    sudo -u rover git clone "$REPO_URL" "$ROS2_WS/src"
else
    echo "Repository already cloned, pulling latest"
    sudo -u rover git -C "$ROS2_WS/src" pull
fi

# --- Build with symlink-install ---
echo "Installing ROS dependencies..."
sudo -u rover bash -c "source /opt/ros/lyrical/setup.bash && cd '$ROS2_WS' && rosdep install --from-paths src --ignore-src -r -y" 2>/dev/null || true

echo "Building workspace with colcon --symlink-install"
sudo -u rover bash -c "source /opt/ros/lyrical/setup.bash && cd '$ROS2_WS' && colcon build --symlink-install"

# --- Install systemd service ---
if [[ ! -f "$SERVICE_SRC" ]]; then
    echo "Missing service file: $SERVICE_SRC"
    exit 1
fi

cp "$SERVICE_SRC" "$SERVICE_DST"
chmod 644 "$SERVICE_DST"

systemctl daemon-reload
systemctl enable rover-node.service

echo "Rover service installed successfully"
echo "Start the service with: sudo systemctl start rover-node.service"