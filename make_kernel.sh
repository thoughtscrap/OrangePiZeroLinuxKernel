#! /bin/bash

########################################
## Commands
########################################
_ECHO=/bin/echo
_GREP=/bin/grep
_TAR=/bin/tar
_DPKG=/usr/bin/dpkg-query
_LSCPU=/usr/bin/lscpu
_WGET=/usr/bin/wget
_INSTALL_PKG="sudo /usr/bin/apt-get -y install"
_MKDIR_P="/bin/mkdir -p"

_READ="read -p"

## Populate the SCRIPT_DIR variable with the Directory path of the current script

########################################
## Constants
########################################
REQ_PKGS="bison flex build-essential libssl-dev device-tree-compiler python python-dev swig device-tree-compiler"
TOOLCHAIN_URL="https://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/arm-linux-gnueabihf"
TOOLCHAIN_DIR=toolchain


########################################
## Functions
########################################

## https://www.ostricher.com/2014/10/the-right-way-to-get-the-directory-of-a-bash-script/
## https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
get_script_dir() {
    local SOURCE="${BASH_SOURCE[0]}"
    while [ -h "${SOURCE}" ]
    do
        local DIR="$( cd -P "$( dirname "${SOURCE}" )" && pwd )"
        SOURCE="$( readlink "${SOURCE}" )"
        [[ ${SOURCE} != /* ]] && SOURCE="$DIR/${SOURCE}"
    done
    DIR="$( cd -P "$( dirname "${SOURCE}" )" && pwd )"
    ${_ECHO} ${DIR}
}

check_pkg_installed(){
    local pkg_name=${1}
    local status=$(${_DPKG} -W -f'${Status}' ${pkg_name} 2>/dev/null | ${_GREP} -c "ok installed")
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
        ${_INSTALL_PKG} ${pkg_name}
        return $?
    else
        ${_ECHO} "${pkg_name} is already installed..."
        return 0
    fi	
}

get_architecture(){
    local arch=$(${_LSCPU} | ${_GREP} "Architecture" | ${_GREP} -c "x86_64")
    if [ ${arch} -eq 0 ]
    then
        return 32
    else
        return 64
    fi
}

install_toolchain(){
    local OUT_DIR=${1}
    ${_MKDIR_P} ${OUT_DIR}
    if [ ! -d ${OUT_DIR} ]
    then
        ${_ECHO} " Unable to create toolchain directory ${OUT_DIR}, cannot continue..."
	exit 1
    fi

    ## Check the machine architecture
    get_architecture
    local arch=$?

    if [ ${arch} -eq 32 ]
    then
	## 32 bit machine ##
	${_ECHO} "Installing 32 bit toolchain..."
	${_WGET} ${TOOLCHAIN_URL}/gcc-linaro-7.3.1-2018.05-i686_arm-linux-gnueabihf.tar.xz -O /tmp/toolchain.tar.xz
        ${_TAR} -xf /tmp/toolchain.tar.xz -C ${OUT_DIR} --strip-components 1
    elif [ ${arch} -eq 64 ]
    then
	## 64 bit machine ##
	${_ECHO} "Installing 64 bit toolchain..."
	${_WGET} ${TOOLCHAIN_URL}/gcc-linaro-7.3.1-2018.05-x86_64_arm-linux-gnueabihf.tar.xz -O /tmp/toolchain.tar.xz
        ${_TAR} -xf /tmp/toolchain.tar.xz -C ${OUT_DIR} --strip-components 1
    else
	## Unknown architecture ##
	${_ECHO} "Unknown Archtecture..."
    fi
}

display_information(){
    ${_ECHO} "This script will perform the following actions:"
    ${_ECHO} ""
    ${_ECHO} "1. Check for the necessary dependencies and install the missing ones."
    ${_ECHO} "2. Install the cross compilation toolchain."
    ${_ECHO} "3. Clone the linux kernel and WiFi driver source repositories."
    ${_ECHO} "4. Compile the linux kernel and WiFi driver."
    ${_ECHO} ""
    ${_READ} "Do you wish to continue? Y/n (n):" option

    if [ -z ${option} ] || [ ${option} != "Y" ]
    then
        ${_ECHO} "Exiting..."
        exit 0
    fi
}


install_dependencies() {
    sudo apt-get update

    for dependency in ${REQ_PKGS}
    do
        ensure_pkg_installed ${dependency}
    done
}


create_base_dir(){
local BASE
while [ -z ${BASE} ]
do
    ${_READ} "Specify which directory to use as the base for work (Should be non-existent):" BASE
    if [ -d ${BASE} ]
    then
        ${_ECHO} "${BASE} exists, Please enter a non-existant directory path"
	unset BASE
	continue
    else
        ${_MKDIR_P} ${BASE}
	if [ -d ${BASE} ]
	then
            export BASE_DIR=${BASE}
            break
	else
            ${_ECHO} "Unable to create ${BASE}, cannot continue..."
	    exit 1
        fi
    fi
done
}

########################################
## Entry Point
########################################

SCRIPT_DIR=$(get_script_dir)

## Display Information about the script and ask for proceeding
display_information

## Create base directory where all the processing would be contained and done
create_base_dir

## Ensure all the required packages are installed ##
install_dependencies

## Install the toolchain for cross compilation
install_toolchain ${BASE_DIR}/${TOOLCHAIN_DIR}
export CROSS_COMPILE_FLAG=${BASE_DIR}/${TOOLCHAIN_DIR}/bin/arm-linux-gnueabihf-

## Clone the kernel source repository and xradio driver source repository
cd ${BASE_DIR}

${_ECHO} "Downloading kernel source tree..."
git clone --depth 1 -b sunxi-next --single-branch https://github.com/linux-sunxi/linux-sunxi

${_ECHO} "Downloading xradio source..."
git clone --depth 1 https://github.com/fifteenhex/xradio

${_ECHO} "Create .config file for kernel"
cp ${SCRIPT_DIR}/.config ${BASE_DIR}/linux-sunxi/.config

${_ECHO} "Compiling kernel (This may take a long time)..."
cd ${BASE_DIR}/linux-sunxi

make -j4 ARCH=arm oldconfig

make -j4 ARCH=arm CROSS_COMPILE=${CROSS_COMPIE_FLAG} LOADADDR=0x48000000 zImage modules dtbs
rm -rf ${BASE_DIR}/output

make -j4 ARCH=arm CROSS_COMPILE=${CROSS_COMPIE_FLAG} INSTALL_MOD_PATH=${BASE_DIR}/output modules_install
cp arch/arm/boot/zImage ${BASE_DIR}/output/zImage

${_ECHO} "Compiling XRadio WiFi Driver..."
cd ${BASE_DIR}/xradio

make -j4 ARCH=arm CROSS_COMPILE=${CROSS_COMPIE_FLAG} -C ${BASE_DIR}/linux-sunxi M=${BASE_DIR}/xradio INSTALL_MOD_PATH=${BASE_DIR}/output modules
make -j4 ARCH=arm CROSS_COMPILE=${CROSS_COMPIE_FLAG} -C ${BASE_DIR}/linux-sunxi M=${BASE_DIR}/xradio INSTALL_MOD_PATH=${BASE_DIR}/output modules_install

${_ECHO} "Compiling device tree"
dtc -I dts -O dtb ${SCRIPT_DIR}/orangepi-zero.dts > ${BASE_DIR}/output/orangepi-zero.dtb


