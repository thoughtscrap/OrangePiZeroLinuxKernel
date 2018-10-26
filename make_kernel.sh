#! /bin/bash

########################################
## Constants
########################################
_ECHO=/bin/echo
_DPKG=/usr/bin/dpkg-query
_LSCPU=/usr/bin/lscpu

REQ_PKGS="bison flex build-essential libssl-dev device-tree-compiler python python-dev swig"

TOOLCHAIN_URL="https://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/arm-linux-gnueabihf"

########################################
## Functions
########################################
check_pkg_installed(){
    local pkg_name=${1}
    local status=$(${_DPKG} -W -f'${Status}' ${pkg_name} 2>/dev/null | grep -c "ok installed")
    if [ ${status} -ne 0 ]
    then
        return 0
    else
        return 1
    fi	    
}

ensure_pkg_installed(){
    local pkg_name=${1}
    check_pkg_installed ${pkg_name}
    if [ $? -eq 1 ]
    then
        ${_ECHO} "${pkg_name} is not installed, installing..."
        sudo apt-get install -y ${pkg_name}
        return $?
    else
        ${_ECHO} "${pkg_name} is already installed..."
        return 0
    fi	
}

get_architecture(){
    local arch=$(${_LSCPU} | grep "Architecture" | grep -c "x86_64")
    if [ ${arch} -eq 0 ]
    then
        return 32
    else
        return 64
    fi
}

install_toolchain(){
    cd ${WORK_DIR}

    ## Check the machine architecture
    get_architecture
    local arch=$?

    if [ ${arch} -eq 32 ]
    then
	## 32 bit machine ##
	${_ECHO} "Installing 32 bit toolchain..."
	wget ${TOOLCHAIN_URL}/gcc-linaro-7.3.1-2018.05-i686_arm-linux-gnueabihf.tar.xz -O toolchain.tar.xz
        tar -xf toolchain.tar.xz
    elif [ ${arch} -eq 64 ]
	## 64 bit machine ##
	${_ECHO} "Installing 64 bit toolchain..."
	wget ${TOOLCHAIN_URL}/gcc-linaro-7.3.1-2018.05-x86_64_arm-linux-gnueabihf.tar.xz -O toolchain.tar.xz
        tar -xf toolchain.tar.xz
    else
	## Unknown architecture ##
    fi
}


########################################
## Entry Point
########################################

echo "Creating a new Working Directory \"orangepi\""
mkdir orangepi
cd orangepi


## Ensure all the required packages are installed ##
sudo apt-get update

for req_pkg in ${REQ_PKGS}
do
    ensure_pkg_installed ${req_pkg}
done


## Install the toolchain for cross compilation
install_toolchain


## Clone the kernel source repository and xradio driver source repository

${_ECHO} "Downloading kernel source tree..."
git clone --depth 1 -b sunxi-next --single-branch https://github.com/linux-sunxi/linux-sunxi

${_ECHO} "Downloading xradio source..."
git clone --depth 1 https://github.com/fifteenhex/xradio

${_ECHO} "Create .config file for kernel"
cp .config linux-sunxi/

${_ECHO} "Compiling kernel..."
