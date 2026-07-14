#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_URL="git@github.com:fatherofcamels/Rover-Client.git"
ROS2_WS="/home/rover/ros2_ws"
SERVICE_SRC="$SCRIPT_DIR/../etc/systemd/rover-node.service"
SERVICE_DST="/etc/systemd/system/rover-node.service"
ROVER_HOME="$(getent passwd rover | cut -d: -f6 2>/dev/null || echo /home/rover)"
ROVER_SSH_KEY="$ROVER_HOME/.ssh/id_ed25519"

# --- Ensure rover has serial device access ---
usermod -a -G dialout rover 2>/dev/null || true

# --- Ensure rover has SSH key for GitHub access ---
if [[ ! -f "$ROVER_SSH_KEY" ]]; then
    echo "Generating SSH key for rover user"
    sudo -u rover mkdir -p "$ROVER_HOME/.ssh"
    sudo -u rover chmod 700 "$ROVER_HOME/.ssh"
    sudo -u rover ssh-keygen -t ed25519 -C "rover@$(hostname)" -f "$ROVER_SSH_KEY" -N ""
else
    echo "SSH key already exists for rover user"
fi
# --- Prompt user to add SSH key to GitHub ---
echo ""
echo "Add this public key to GitHub (Settings -> SSH and GPG keys):"
echo "------------------------------------------------------------"
sudo -u rover cat "$ROVER_SSH_KEY.pub"
echo "------------------------------------------------------------"
echo ""

while true; do
    echo "Have you added the SSH key to GitHub? (y/n)"
    echo "Type 'y' to continue or 'n' to exit."
    read -r answer
    case "$answer" in
        [Yy]* ) break;;
        [Nn]* ) echo "Please add the SSH key to GitHub and run this
    script again."; exit 1;;
    esac
done

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