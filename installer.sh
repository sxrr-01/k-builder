#!/usr/bin/env bash

mkdir ~/k-bilder

cat << 'EOF' >> ~/k-builder/script.sh
#!/bin/bash
set -euo pipefail

SRC="$HOME/linux-build"
CONF_DIR="$HOME/kernel-configs"
CONF="$CONF_DIR/$(hostname -s).config"

#debug only
echo "$SRC"
echo "$CONF_DIR"
echo "$CONF"

mkdir -p "$CONF_DIR"

# cloning and setup
cd "$HOME"

if [ -d "$SRC" ]; then
    echo "Deleting $SRC in 10 seconds. Ctrl+C to abort."
    sleep 10
    rm -rf "$SRC"
fi

git clone --depth 1 --branch linux-rolling-stable \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux-build
cd "$SRC"
touch .scmversion
echo "Building kernel version: $(make kernelversion)"

if [ -f "$CONF" ]; then
  cp "$CONF" .config
  make oldconfig
else
  echo "No saved config for $(hostname -s), creating one."
  if [ -r /proc/config.gz ]; then
    zcat /proc/config.gz > .config
  elif [ -r "/boot/config-$(uname -r)" ]; then
    cp "/boot/config-$(uname -r)" .config
  else
    make defconfig
  fi
  make olddefconfig
  scripts/config --set-str LOCALVERSION "-custom" \
                   -d LOCALVERSION_AUTO \
                   -e IKCONFIG -e IKCONFIG_PROC \
                   -e PREEMPT -e HZ_1000 \
                   -e LRU_GEN -e LRU_GEN_ENABLED \
                   -e IOSCHED_BFQ
  make olddefconfig
  make localmodconfig
  make menuconfig
fi

if command -v ccache >/dev/null; then
    CC="ccache gcc"; export CCACHE_DIR="$HOME/.ccache"
else
    CC="gcc"
fi
make -j"$(nproc --ignore=1)" CC="$CC"
sudo make INSTALL_MOD_STRIP=1 modules_install
sudo make install


REL=$(make -s kernelrelease)
cp .config "$CONF"
cp .config "$CONF_DIR/$(hostname -s)-$REL.config"
sudo cp .config "/boot/config-$REL"
echo "Installed $REL"
EOF

chmod +x ~/k-builder/script.sh
echo "alias kernelbuild='~/k-builder/script.sh'" >> ~/.bashrc
echo "Installed. Refresh your Shell to run 'kernelbuild'."
