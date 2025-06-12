#!/bin/bash

# 功能说明：Swap管理工具
# 支持功能：
# 1. 禁用Swap
# 2. 设置Swap大小

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

# 禁用Swap
disable_swap() {
    printf "${YELLOW}正在禁用Swap...${NC}\n"
    
    # 关闭所有swap
    swapoff -a
    
    # 注释掉/etc/fstab中的swap行
    sed -i '/swap/s/^/#/' /etc/fstab
    
    # 删除swap文件
    rm -f /swapfile
    
    printf "${GREEN}Swap已成功禁用！${NC}\n"
    printf "${YELLOW}当前Swap状态：${NC}\n"
    free -h
}

# 设置Swap大小
set_swap_size() {
    printf "${YELLOW}当前Swap状态：${NC}\n"
    free -h
    
    read -p "请输入新的Swap大小（例如：4G）：" swap_size
    
    # 验证输入格式
    if ! [[ $swap_size =~ ^[0-9]+[MG]$ ]]; then
        printf "${RED}错误：无效的大小格式！请使用数字+M或G（例如：4G）${NC}\n"
        return 1
    fi
    
    printf "${YELLOW}正在设置Swap大小...${NC}\n"
    
    # 关闭当前swap
    swapoff -a
    
    # 删除旧的swap文件
    rm -f /swapfile
    
    # 创建新的swap文件
    fallocate -l "$swap_size" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    
    # 启用新的swap
    swapon /swapfile
    
    # 更新/etc/fstab
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    else
        sed -i '/\/swapfile/d' /etc/fstab
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    
    printf "${GREEN}Swap大小已成功设置为 $swap_size！${NC}\n"
    printf "${YELLOW}当前Swap状态：${NC}\n"
    free -h
}

# 主菜单
show_menu() {
    if [ "$FIRST_RUN" = true ]; then
        printf "${YELLOW}"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf " *                                                             * \n"
        printf " *                    欢迎使用Swap管理工具                     * \n"
        printf " *                                                             * \n"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf "${NC}"
        FIRST_RUN=false
    fi
    printf "${BLUE}===================================\n"
    printf "         Swap管理工具\n"
    printf "===================================${NC}\n"
    printf "1. 禁用Swap\n"
    printf "2. 设置Swap大小\n"
    printf "0. 退出\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程
while true; do
    show_menu
    read -p "请输入选项数字 (0-2): " choice
    case $choice in
        1) disable_swap; read -p "按回车键继续..." dummy ;;
        2) set_swap_size; read -p "按回车键继续..." dummy ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-2的数字！${NC}\n"; sleep 1 ;;
    esac
done 