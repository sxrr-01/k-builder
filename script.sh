#!/bin/bash
set -euo pipefail

SRC="$HOME/linux-build"
CONF_DIR="$HOME/kernel-configs"
CONF="$CONF_DIR/$(hostname -s).config"

echo "SRC"
echo "CONF_DIR"
echo "CONF"

# cloning and setup
cd ~/

if [ -d "SRC" ]; then
    echo "Deleting $SRC in 10 seconds. Ctrl+C to abort."
    sleep 10
    rm -rf "SRC"
fi

git clone --depth 1 --branch linux-rolling-stable \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux-build
cd linux-build
touch .scmversion
echo "Building kernel version: $(make kernelversion)"

if [ ! -d "~/kernel-configs" ]; then
    mkdir -p ~/kernel-configs
    make
    make localmodconfig
    make menuconfig
else
    cp ~/kernel-configs/custom.config .config
    make oldconfig
fi



# build & install
export CCACHE_DIR=~/.ccache
make -j$(nproc --ignore=1) CC="ccache gcc"
sudo make INSTALL_MOD_STRIP=1 modules_install
sudo make install

# post-install
REL=$(make -s kernelrelease)
cp .config ~/kernel-configs/custom.config
sudo cp .config /boot/config-$REL
echo "Installed $REL"
