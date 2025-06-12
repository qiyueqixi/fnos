#!/bin/bash

# 功能说明：IOMMU硬件直通管理工具
# 支持功能：
# 1. 检查IOMMU状态
# 2. 启用IOMMU
# 3. 禁用IOMMU

# 检查执行环境
if [ -z "$BASH_VERSION" ]; then
    echo "错误：请使用bash执行此脚本！" >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本需要root权限！" >&2
    exit 1
fi

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 恢复默认颜色

# 添加首次运行标志
FIRST_RUN=true

# 检查IOMMU状态
check_iommu_status() {
    printf "${YELLOW}正在检查IOMMU状态...${NC}\n"
    
    # 检查内核参数
    if grep -q "intel_iommu=on" /proc/cmdline || grep -q "amd_iommu=on" /proc/cmdline; then
        printf "${GREEN}IOMMU已在BIOS中启用${NC}\n"
    else
        printf "${RED}IOMMU未在BIOS中启用${NC}\n"
    fi
    
    # 检查dmesg输出
    if dmesg | grep -i "iommu" | grep -i "enabled" > /dev/null; then
        printf "${GREEN}IOMMU已在系统中启用${NC}\n"
    else
        printf "${RED}IOMMU未在系统中启用${NC}\n"
    fi
    
    # 检查设备组
    if [ -d "/sys/kernel/iommu_groups" ]; then
        printf "${GREEN}IOMMU组已创建${NC}\n"
        printf "${YELLOW}IOMMU组信息：${NC}\n"
        ls -l /sys/kernel/iommu_groups/
    else
        printf "${RED}未找到IOMMU组${NC}\n"
    fi
    
    # 检查CPU虚拟化支持
    if grep -q "vmx\|svm" /proc/cpuinfo; then
        printf "${GREEN}CPU支持虚拟化${NC}\n"
    else
        printf "${RED}CPU不支持虚拟化${NC}\n"
    fi
}

# 启用IOMMU
enable_iommu() {
    printf "${YELLOW}正在启用IOMMU...${NC}\n"
    
    # 检查当前状态
    if grep -q "intel_iommu=on" /proc/cmdline || grep -q "amd_iommu=on" /proc/cmdline; then
        printf "${YELLOW}IOMMU已经启用${NC}\n"
        return
    fi
    
    # 检测CPU厂商
    if grep -q "Intel" /proc/cpuinfo; then
        IOMMU_PARAM="intel_iommu=on"
    elif grep -q "AMD" /proc/cpuinfo; then
        IOMMU_PARAM="amd_iommu=on"
    else
        printf "${RED}无法检测CPU厂商${NC}\n"
        return
    fi
    
    # 修改GRUB配置
    GRUB_FILE="/etc/default/grub"
    if [ -f "$GRUB_FILE" ]; then
        # 备份原配置
        cp "$GRUB_FILE" "${GRUB_FILE}.bak"
        
        # 修改配置
        sed -i "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $IOMMU_PARAM\"/" "$GRUB_FILE"
        
        # 更新GRUB
        update-grub
        
        printf "${GREEN}IOMMU已启用，请重启系统使更改生效${NC}\n"
    else
        printf "${RED}找不到GRUB配置文件${NC}\n"
    fi
}

# 禁用IOMMU
disable_iommu() {
    printf "${YELLOW}正在禁用IOMMU...${NC}\n"
    
    # 检查当前状态
    if ! grep -q "intel_iommu=on" /proc/cmdline && ! grep -q "amd_iommu=on" /proc/cmdline; then
        printf "${YELLOW}IOMMU已经禁用${NC}\n"
        return
    fi
    
    # 修改GRUB配置
    GRUB_FILE="/etc/default/grub"
    if [ -f "$GRUB_FILE" ]; then
        # 备份原配置
        cp "$GRUB_FILE" "${GRUB_FILE}.bak"
        
        # 修改配置
        sed -i "s/ intel_iommu=on//g; s/ amd_iommu=on//g" "$GRUB_FILE"
        
        # 更新GRUB
        update-grub
        
        printf "${GREEN}IOMMU已禁用，请重启系统使更改生效${NC}\n"
    else
        printf "${RED}找不到GRUB配置文件${NC}\n"
    fi
}

# 主菜单
show_menu() {
    if [ "$FIRST_RUN" = true ]; then
        printf "${YELLOW}"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf " *                                                             * \n"
        printf " *                欢迎使用IOMMU硬件直通管理工具                * \n"
        printf " *                                                             * \n"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf "${NC}"
        FIRST_RUN=false
    fi
    printf "${BLUE}===================================\n"
    printf "     IOMMU硬件直通管理工具\n"
    printf "===================================${NC}\n"
    printf "1. 检查IOMMU状态\n"
    printf "2. 启用IOMMU\n"
    printf "3. 禁用IOMMU\n"
    printf "0. 退出\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程
while true; do
    show_menu
    read -p "请输入选项数字 (0-3): " choice
    case $choice in
        1) check_iommu_status; read -p "按回车键继续..." dummy ;;
        2) enable_iommu; read -p "按回车键继续..." dummy ;;
        3) disable_iommu; read -p "按回车键继续..." dummy ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-3的数字！${NC}\n"; sleep 1 ;;
    esac
done 