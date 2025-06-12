#!/bin/bash

# 功能说明：QCOW镜像管理工具

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 恢复默认颜色

# 检查qemu-img是否安装
check_qemu_img() {
    if ! command -v qemu-img &> /dev/null; then
        printf "${RED}错误：未找到qemu-img工具，请先安装qemu-utils${NC}\n"
        printf "可以使用以下命令安装：\n"
        printf "Ubuntu/Debian: sudo apt-get install qemu-utils\n"
        printf "CentOS/RHEL: sudo yum install qemu-img\n"
        exit 1
    fi
}

# 显示QCOW镜像信息
show_qcow_info() {
    local image_path="$1"
    if [ ! -f "$image_path" ]; then
        printf "${RED}错误：找不到镜像文件 $image_path${NC}\n"
        return 1
    fi
    
    printf "${BLUE}正在获取镜像信息...${NC}\n"
    qemu-img info "$image_path"
}

# 转换镜像格式
convert_image() {
    local input_path="$1"
    local output_path="$2"
    local format="$3"
    
    if [ ! -f "$input_path" ]; then
        printf "${RED}错误：找不到输入镜像文件 $input_path${NC}\n"
        return 1
    fi
    
    printf "${BLUE}正在转换镜像格式...${NC}\n"
    qemu-img convert -f qcow2 -O "$format" "$input_path" "$output_path"
    
    if [ $? -eq 0 ]; then
        printf "${GREEN}转换成功！${NC}\n"
        printf "新镜像保存在：$output_path\n"
    else
        printf "${RED}转换失败！${NC}\n"
    fi
}

# 调整镜像大小
resize_image() {
    local image_path="$1"
    local new_size="$2"
    
    if [ ! -f "$image_path" ]; then
        printf "${RED}错误：找不到镜像文件 $image_path${NC}\n"
        return 1
    fi
    
    printf "${BLUE}正在调整镜像大小...${NC}\n"
    qemu-img resize "$image_path" "$new_size"
    
    if [ $? -eq 0 ]; then
        printf "${GREEN}调整大小成功！${NC}\n"
    else
        printf "${RED}调整大小失败！${NC}\n"
    fi
}

# 创建新镜像
create_image() {
    local image_path="$1"
    local size="$2"
    local format="$3"
    
    printf "${BLUE}正在创建新镜像...${NC}\n"
    qemu-img create -f "$format" "$image_path" "$size"
    
    if [ $? -eq 0 ]; then
        printf "${GREEN}创建成功！${NC}\n"
        printf "新镜像保存在：$image_path\n"
    else
        printf "${RED}创建失败！${NC}\n"
    fi
}

# 显示菜单
show_menu() {
    printf "${BLUE}===================================\n"
    printf "        QCOW镜像管理工具\n"
    printf "===================================${NC}\n"
    printf "1. 显示镜像信息\n"
    printf "2. 转换镜像格式\n"
    printf "3. 调整镜像大小\n"
    printf "4. 创建新镜像\n"
    printf "0. 返回主菜单\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程
check_qemu_img

while true; do
    show_menu
    read -p "请输入选项数字 (0-4): " choice
    case $choice in
        1)
            read -p "请输入镜像文件路径: " image_path
            show_qcow_info "$image_path"
            ;;
        2)
            read -p "请输入源镜像路径: " input_path
            read -p "请输入目标镜像路径: " output_path
            read -p "请输入目标格式 (qcow2/raw/vmdk): " format
            convert_image "$input_path" "$output_path" "$format"
            ;;
        3)
            read -p "请输入镜像文件路径: " image_path
            read -p "请输入新大小 (例如: +10G 或 20G): " new_size
            resize_image "$image_path" "$new_size"
            ;;
        4)
            read -p "请输入新镜像路径: " image_path
            read -p "请输入镜像大小 (例如: 10G): " size
            read -p "请输入镜像格式 (qcow2/raw): " format
            create_image "$image_path" "$size" "$format"
            ;;
        0)
            printf "${GREEN}返回主菜单...${NC}\n"
            exit 0
            ;;
        *)
            printf "${RED}无效选项，请输入0-4的数字！${NC}\n"
            ;;
    esac
    read -p "按回车键继续..." dummy
done 