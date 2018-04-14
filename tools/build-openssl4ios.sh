#!/bin/bash
#
# Copyright 2016 leenjewel
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -u

# 执行的shell文件名称
SOURCE="$0"

# 检查执行的shell文件是否为软链接，如果是软链接则切换到软链接指向的源文件目录
while [ -h "$SOURCE" ]; do
    # 进入执行的shell软链接文件所在目录
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    # 读取执行的shell软链接文件指向的源文件
    SOURCE="$(readlink "$SOURCE")"
    # 获取执行的shell软链接文件指向的源文件目录
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
# 进入执行的shell文件指向的源文件目录
pwd_path="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
 
# 初始化编译需要支持的架构(ARCH)
#ARCHS=("arm64" "armv7s" "armv7" "i386" "x86_64")
ARCHS=("arm64" "armv7s" "armv7")
# 初始化编译需要支持的每种架构使用的SDK
SDKS=("iphoneos" "iphoneos" "iphoneos")
# 初始化编译需要支持的每种架构对应的平台
PLATFORMS=("iPhoneOS" "iPhoneOS" "iPhoneOS")
# 读取xcode的安装目录
DEVELOPER=`xcode-select -print-path`
# 设置编译使用的SDK版本号
SDK_VERSION=""11.2""
# 指定编译的OpenSSL压缩文件名i(.tar.gz格式压缩文件)。后面编译时会解压缩下载的OpenSSL压缩文件
LIB_NAME="openssl-OpenSSL_1_0_2o"
# 指定编译后的库文件保存路径
LIB_DEST_DIR="${pwd_path}/../output/ios/openssl-universal"
# 指定编译后的头文件保存目录
HEADER_DEST_DIR="include"

# 编译之前先删除以前编译生成的头文件、库文件和源代码。
rm -rf "${HEADER_DEST_DIR}" "${LIB_DEST_DIR}" "${LIB_NAME}"
 
configure_make()
{
   ARCH=$1; SDK=$2; PLATFORM=$3;
   # 检查是否存在之前的源代码文件目录，如果存在，则先删除。
   if [ -d "${LIB_NAME}" ]; then
       rm -fr "${LIB_NAME}"
   fi

   # 解压缩OpenSSL源代码的压缩包
   tar xfz "${LIB_NAME}.tar.gz"

   # 将当前路径压栈，然后进入解压之后的源代码目录
   pushd .; cd "${LIB_NAME}";

   # 检查编译的架构，如果不是i386和x86_64架构，则将crypto/ui/ui_openssl.c文件中的static volatile sig_atomic_t intr_signal;替换为static volatile intr_signal;
   if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
       echo ""
   else
       sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
   fi

   # 配置编译环境
   export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
   export CROSS_SDK="${PLATFORM}${SDK_VERSION}.sdk"
   export TOOLS="${DEVELOPER}"
   export CC="${TOOLS}/usr/bin/gcc -arch ${ARCH}"

   # 创建OpenSSL编译架构对应的结果输出目录。
   PREFIX_DIR="${pwd_path}/../output/ios/openssl-${ARCH}"
   if [ -d "${PREFIX_DIR}" ]; then
       rm -fr "${PREFIX_DIR}"
   fi
   mkdir -p "${PREFIX_DIR}"

   # 执行configure命令
   if [[ "${ARCH}" == "x86_64" ]]; then
       ./Configure darwin64-x86_64-cc --prefix="${PREFIX_DIR}"
   elif [[ "${ARCH}" == "i386" ]]; then
       ./Configure darwin-i386-cc --prefix="${PREFIX_DIR}"
   else
       ./Configure iphoneos-cross --prefix="${PREFIX_DIR}"
   fi
   export CFLAGS="-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK}"

   # 执行编译
   make clean
   make -j8

# 此处不执行make install，此脚本只编译OpenSSL库，并不安装到系统中
#   if make -j8
#   then
#       # make install;
#       make install_sw;
#       make install_ssldirs;
#       popd;
#       rm -fr "${LIB_NAME}"
#   fi

   # 将之前压栈的路径出栈
   popd;
}

# 执行针对每个架构的编译
for ((i=0; i < ${#ARCHS[@]}; i++))
do
    if [[ $# -eq 0 || "$1" == "${ARCHS[i]}" ]]; then
        configure_make "${ARCHS[i]}" "${SDKS[i]}" "${PLATFORMS[i]}"
    fi
done

# 将各架构编译的库文件合并为一个库文件
create_lib()
{
   LIB_SRC=$1;
   LIB_DST=$2;
   LIB_PATHS=( "${ARCHS[@]/#/${pwd_path}/../output/ios/openssl-}" )
   LIB_PATHS=( "${LIB_PATHS[@]/%//lib/${LIB_SRC}}" )
   lipo ${LIB_PATHS[@]} -create -output "${LIB_DST}"
}

# 创建最后的库文件保存目录，然后将编译的最终库文件拷贝到目录中
mkdir "${LIB_DEST_DIR}";
create_lib "libcrypto.a" "${LIB_DEST_DIR}/libcrypto.a"
create_lib "libssl.a" "${LIB_DEST_DIR}/libssl.a"
 
