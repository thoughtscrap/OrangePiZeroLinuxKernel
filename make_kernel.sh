#! /bin/bash

echo "Creating a new Directory \"orangepi\""
mkdir orangepi
cd orangepi

echo "Installing toolchain..."
wget https://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/arm-linux-gnueabihf/gcc-linaro-7.3.1-2018.05-x86_64_arm-linux-gnueabihf.tar.xz -O toolchain.tar.xz
tar -xvf toolchain.tar.xz

sudo apt-get update

sudo apt-get -y install bison flex build-essential libssl-dev device-tree-compiler python python-dev swig

export PATH=${PATH}:`pwd`/gcc-linaro-7.3.1-2018.05-x86_64_arm-linux-gnueabihf/bin

echo "Downloading kernel source tree..."
git clone --depth 1 -b sunxi-next --single-branch https://github.com/linux-sunxi/linux-sunxi

echo "Downloading xradio source..."
git clone --depth 1 https://github.com/fifteenhex/xradio

echo "Create .config file for kernel"
cp .config linux-sunxi/

echo "Compiling kernel..."