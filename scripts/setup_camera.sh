#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CAMERA_WS="/home/rover/camera_ws"
LIBCAMERA_PREFIX="$CAMERA_WS/install/libcamera"
RPI_CONFIG="/boot/firmware/config.txt"

echo "=== Setting up camera driver & ROS2 camera node ==="

# --- Install system dependencies ---
echo "Installing build dependencies..."
apt update
apt install -y build-essential linux-headers-$(uname -r) dkms git \
    meson ninja-build python3-pip python3-yaml python3-jinja2 \
    libudev-dev libyaml-dev libboost-dev libgnutls28-dev libssl-dev \
    libevent-dev libexif-dev libjpeg-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-tools pybind11-dev python3-ply

# Remove the system libcamera-dev to avoid conflicts with our custom build
apt remove -y libcamera-dev libcamera-tools libcamera-ipa 2>/dev/null || true

# --- Clone and build libcamera from source ---
echo "Setting up libcamera source..."
if [[ ! -d "$CAMERA_WS/src" ]]; then
    mkdir -p "$CAMERA_WS/src"
    chown -R rover:rover "$CAMERA_WS"
fi

if [[ ! -d "$CAMERA_WS/src/libcamera/.git" ]]; then
    echo "Cloning libcamera..."
    sudo -u rover git clone https://git.libcamera.org/libcamera/libcamera.git \
        "$CAMERA_WS/src/libcamera"
fi

if [[ ! -d "$CAMERA_WS/src/libcamera/build" ]]; then
    echo "Configuring libcamera build..."
    sudo -u rover bash -c "cd '$CAMERA_WS/src/libcamera' && meson setup build \
        --prefix '$LIBCAMERA_PREFIX' \
        -Dpipelines=rpi/vc4,rpi/pisp \
        -Dipas=rpi/vc4,rpi/pisp \
        -Dv4l2=enabled \
        -Dgstreamer=enabled \
        -Dtest=false \
        -Dlc-compliance=disabled \
        -Dcam=disabled \
        -Dqcam=disabled \
        -Ddocumentation=disabled \
        -Dpycamera=enabled \
        -Dbuildtype=release"
fi

echo "Building and installing libcamera..."
sudo -u rover bash -c "cd '$CAMERA_WS/src/libcamera' && ninja -C build && meson install -C build"

# --- Clone and build camera_ros ---
echo "Setting up camera_ros workspace..."
export PKG_CONFIG_PATH="$LIBCAMERA_PREFIX/lib/aarch64-linux-gnu/pkgconfig:$LIBCAMERA_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="$LIBCAMERA_PREFIX/lib:$LIBCAMERA_PREFIX/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}"

if [[ ! -d "$CAMERA_WS/src/camera_ros/.git" ]]; then
    echo "Cloning camera_ros..."
    sudo -u rover git clone https://github.com/christianrauch/camera_ros.git \
        "$CAMERA_WS/src/camera_ros"
fi

echo "Installing ROS dependencies for camera_ros..."
apt install -y ros-lyrical-camera-info-manager
sudo -u rover bash -c "source /opt/ros/lyrical/setup.bash && cd '$CAMERA_WS' && \
    PKG_CONFIG_PATH='$PKG_CONFIG_PATH' LD_LIBRARY_PATH='$LD_LIBRARY_PATH' \
    rosdep install --from-paths src --ignore-src -r -y" 2>/dev/null || true

echo "Building camera_ros with colcon..."
sudo -u rover bash -c "source /opt/ros/lyrical/setup.bash && cd '$CAMERA_WS' && \
    PKG_CONFIG_PATH='$PKG_CONFIG_PATH' LD_LIBRARY_PATH='$LD_LIBRARY_PATH' \
    colcon build --symlink-install"

# --- Enable CSI camera via device tree ---
echo "Configuring device tree for CSI camera..."
if ! grep -q "^dtoverlay=ov5647" "$RPI_CONFIG" 2>/dev/null; then
    echo "dtoverlay=ov5647" >> "$RPI_CONFIG"
    echo "  Added dtoverlay=ov5647 to $RPI_CONFIG"
else
    echo "  dtoverlay=ov5647 already present"
fi

# --- Ensure libcamera can access the camera ---
echo "Configuring libcamera access..."
# libcamera accesses the CSI camera directly via the media controller API;
# ensure the rover user has access to video/media devices
usermod -a -G video rover 2>/dev/null || true

# --- Copy camera node config ---
echo "Installing camera node configuration..."
mkdir -p /home/rover/.ros
cp "$SCRIPT_DIR/../configs/camera_node.yaml" /home/rover/.ros/camera_node.yaml
chown -R rover:rover /home/rover/.ros

# --- Install camera systemd service ---
echo "Installing camera-node systemd service..."
cp "$SCRIPT_DIR/../etc/systemd/camera-node.service" /etc/systemd/system/camera-node.service
chmod 644 /etc/systemd/system/camera-node.service
systemctl daemon-reload
systemctl enable camera-node.service

echo "Camera setup complete."
echo "A reboot is required for device tree changes to take effect."
