#!/usr/bin/env bash

set -euo pipefail

REPO_URL="http://ports.ubuntu.com/ubuntu-ports/"
COMPONENTS="main,universe,restricted,multiverse"

# ---- Create rover user with passwordless sudo ----
if ! id rover &>/dev/null 2>&1; then
    echo "Creating rover user with sudo privileges"
    useradd --system --create-home --shell /bin/bash rover
    echo "rover ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/rover
    chmod 440 /etc/sudoers.d/rover
fi

# ---- APT sources ----
if ! command -v add-apt-repository &> /dev/null; then
    apt update && apt install -y software-properties-common
fi

for suite in noble noble-updates noble-backports; do
    add-apt-repository -n -y "deb ${REPO_URL} ${suite} ${COMPONENTS//,/ }"
done

apt update

# ---- Locale ----
echo "Current locale:"
locale

apt install -y locales
locale-gen en_US en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

echo "Updated locale:"
locale

# ---- ROS2 apt source ----
add-apt-repository universe -y
apt update

ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F'"' '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb"
dpkg -i /tmp/ros2-apt-source.deb

apt update
apt upgrade -y

apt install -y \
    ros-dev-tools \
    ros-lyrical-ros-base

echo "ROS2 installation completed successfully."

# ---- rosdep ----
echo "Updating rosdep..."
if ! [ -f "/etc/ros/rosdep/sources.list.d/20-default.list" ]; then
  rosdep init
fi
rosdep update

# ---- Setup rover user's environment ----
ROVER_HOME=$(eval echo ~rover)
echo "source /opt/ros/lyrical/setup.bash" >> "$ROVER_HOME/.bashrc"
chown rover:rover "$ROVER_HOME/.bashrc"

echo "ROS2 setup completed successfully."
echo "Restart your terminal or run 'source ~/.bashrc' as the rover user to apply changes."