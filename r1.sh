#!/bin/bash

install_debian() {
    sudo apt update
    [[ -x "$(command -v git)" ]] || sudo apt install -y git
    [[ -x "$(command -v python3)" ]] || sudo apt install -y python3
    [[ -x "$(command -v pip3)" ]] || sudo apt install -y python3-pip
    [[ -x "$(command -v dos2unix)" ]] || sudo apt install -y dos2unix
    [[ -x "$(command -v curl)" ]] || sudo apt install -y curl
    [[ -x "$(command -v unzip)" ]] || sudo apt install -y unzip
}

install_arch() {
    sudo pacman -Sy --noconfirm
    [[ -x "$(command -v git)" ]] || sudo pacman -S --noconfirm git
    [[ -x "$(command -v python3)" ]] || sudo pacman -S --noconfirm python
    [[ -x "$(command -v dos2unix)" ]] || sudo pacman -S --noconfirm dos2unix
    [[ -x "$(command -v curl)" ]] || sudo pacman -S --noconfirm curl
    [[ -x "$(command -v unzip)" ]] || sudo pacman -S --noconfirm unzip
    [[ -x "$(command -v virtualenv)" ]] || sudo pacman -S --noconfirm python-virtualenv
}

install_fedora() {
    sudo dnf update -y
    [[ -x "$(command -v git)" ]] || sudo dnf install -y git
    [[ -x "$(command -v python3)" ]] || sudo dnf install -y python3
    [[ -x "$(command -v pip3)" ]] || sudo dnf install -y python3-pip
    [[ -x "$(command -v dos2unix)" ]] || sudo dnf install -y dos2unix
    [[ -x "$(command -v curl)" ]] || sudo dnf install -y curl
    [[ -x "$(command -v unzip)" ]] || sudo dnf install -y unzip
}

install_macos() {
    # Check if Homebrew is installed
    if ! command -v brew &>/dev/null; then
        echo "[*] Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    brew update
    [[ -x "$(command -v git)" ]] || brew install git
    [[ -x "$(command -v python3)" ]] || brew install python3
    [[ -x "$(command -v dos2unix)" ]] || brew install dos2unix
    [[ -x "$(command -v curl)" ]] || brew install curl
    [[ -x "$(command -v unzip)" ]] || brew install unzip
    [[ -x "$(command -v adb)" ]] || brew install android-platform-tools
}

if [[ "$OSTYPE" == "darwin"* ]]; then
    install_macos
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &>/dev/null; then
        install_debian
    elif command -v pacman &>/dev/null; then
        install_arch
    elif command -v dnf &>/dev/null; then
        install_fedora
    else
        echo "Unsupported Linux distribution"
        exit 1
    fi
else
    echo "Unsupported OS"
    exit 1
fi

if [[ "$OSTYPE" != "linux-gnu"* || ! "$(command -v pacman)" ]]; then
    pip3 show virtualenv &>/dev/null || pip3 install virtualenv
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &>/dev/null; then
        sudo apt install -y adb fastboot
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm android-tools
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y android-tools
    fi
fi

# Setup virtualenv and install requirements
python3 -m venv venv
source venv/bin/activate

chmod +x mtkbootcmd.py

# Download mtkclient
REPO_URL="https://github.com/AgentFabulous/mtkclient"
REPO_NAME=$(basename "$REPO_URL" .git)
git clone "$REPO_URL"
cd "$REPO_NAME" || exit
pip3 install -r requirements.txt

rm -f frp.bin

read -p "[*] Power off your device, press ENTER plug it into your PC"

# Read FRP
sudo python3 mtk r frp frp.bin

sudo chown $USER frp.bin

# Cross-platform file size and byte modification
if [[ "$OSTYPE" == "darwin"* ]]; then
    FILE_SIZE=$(stat -f%z frp.bin)
    LAST_BYTE=$(xxd -p -l 1 -s $((FILE_SIZE - 1)) frp.bin)
else
    FILE_SIZE=$(stat -c%s frp.bin)
    LAST_BYTE=$(xxd -p -l 1 -s -1 frp.bin)
fi

if [[ "$LAST_BYTE" == "00" ]]; then
    printf '\x01' | dd of=frp.bin bs=1 seek=$((FILE_SIZE - 1)) conv=notrunc
fi

# Write FRP
sudo python3 mtk w frp frp.bin

read -p "[*] Unplug your device, press ENTER, plug it back in"

cd ..

sudo ./mtkbootcmd.py FASTBOOT

echo "[*] Waiting for fastboot..."
while ! fastboot devices | grep -q "fastboot"; do
    sleep 1
done

fastboot flashing unlock
fastboot -w
fastboot flash --disable-verity --disable-verification vbmeta vbmeta.img
fastboot reboot-fastboot
fastboot flash system system.img
fastboot reboot
