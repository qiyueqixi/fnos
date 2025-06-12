#!/bin/bash

# 功能说明：飞牛工具箱安装和升级脚本

# 检查执行环境
if [ -z "$BASH_VERSION" ]; then
    echo "错误：请使用bash执行此脚本！" >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "警告：部分功能需要root权限，建议使用sudo执行！" >&2
fi

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 恢复默认颜色

# 将脚本安装到系统
install_script() {
    printf "\n${GREEN}[1] 将脚本安装到飞牛${NC}\n"
    
    # 检查root权限
    if [ "$EUID" -ne 0 ]; then
        printf "${RED}错误：此操作需要root权限！${NC}\n"
        printf "请使用 sudo 运行此脚本。\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 获取当前脚本的路径
    current_script="$(readlink -f "$0")"
    if [ ! -f "$current_script" ]; then
        printf "${RED}错误：无法获取当前脚本路径！${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 复制脚本到/root目录
    printf "\n${YELLOW}正在安装脚本...${NC}\n"
    if cp "$current_script" "/root/network_menu.sh"; then
        # 设置执行权限
        chmod +x "/root/network_menu.sh"
        
        # 检查.bashrc是否存在
        if [ ! -f "/root/.bashrc" ]; then
            touch "/root/.bashrc"
        fi
        
        # 检查是否已经添加了自动执行命令
        if ! grep -q "network_menu.sh" "/root/.bashrc"; then
            # 添加执行命令到.bashrc
            echo "" >> "/root/.bashrc"
            echo "# 自动运行网络管理脚本" >> "/root/.bashrc"
            echo "/root/network_menu.sh" >> "/root/.bashrc"
        fi
        
        printf "${GREEN}脚本已成功安装到系统！${NC}\n"
        printf "脚本位置：/root/network_menu.sh\n"
        printf "下次root用户登录时将自动运行此脚本。\n"
    else
        printf "${RED}安装失败！请检查权限或手动安装。${NC}\n"
    fi
    
    read -p "按回车键返回菜单..."
}

# 卸载脚本
uninstall_script() {
    printf "\n${GREEN}[2] 卸载脚本${NC}\n"
    
    # 检查root权限
    if [ "$EUID" -ne 0 ]; then
        printf "${RED}错误：此操作需要root权限！${NC}\n"
        printf "请使用 sudo 运行此脚本。\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 检查脚本是否已安装
    if [ ! -f "/root/network_menu.sh" ]; then
        printf "${YELLOW}脚本未安装，无需卸载。${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 显示警告信息
    printf "\n${RED}警告：此操作将：${NC}\n"
    printf "1. 删除 /root/network_menu.sh 文件\n"
    printf "2. 从 /root/.bashrc 中移除自动执行命令\n"
    printf "\n${RED}此操作不可恢复！${NC}\n"
    printf "${RED}此操作不可恢复！${NC}\n"
    printf "${RED}此操作不可恢复！${NC}\n"
    
    read -p "是否继续卸载？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf "${YELLOW}操作已取消${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 从.bashrc中移除自动执行命令
    printf "\n${YELLOW}正在移除自动执行命令...${NC}\n"
    if [ -f "/root/.bashrc" ]; then
        sed -i '/network_menu.sh/d' "/root/.bashrc"
        sed -i '/自动运行网络管理脚本/d' "/root/.bashrc"
    fi

    # 删除脚本文件
    printf "${YELLOW}正在删除脚本文件...${NC}\n"
    if rm -f "/root/network_menu.sh"; then
        printf "${GREEN}脚本已成功卸载！${NC}\n"
        printf "下次root用户登录时将不再自动运行此脚本。\n"
    else
        printf "${RED}卸载失败！请检查权限或手动删除。${NC}\n"
    fi
    
    read -p "按回车键返回菜单..."
}

# 升级脚本
upgrade_script() {
    printf "\n${GREEN}[3] 升级脚本${NC}\n"
    
    # 检查root权限
    if [ "$EUID" -ne 0 ]; then
        printf "${RED}错误：此操作需要root权限！${NC}\n"
        printf "请使用 sudo 运行此脚本。\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 显示警告信息
    printf "\n${RED}警告：此操作将：${NC}\n"
    printf "1. 删除当前脚本\n"
    printf "2. 下载最新版本\n"
    printf "3. 替换为最新版本\n"
    printf "\n${RED}此操作不可恢复！${NC}\n"
    printf "${RED}此操作不可恢复！${NC}\n"
    printf "${RED}此操作不可恢复！${NC}\n"
    
    read -p "是否继续升级？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf "${YELLOW}操作已取消${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 获取当前脚本的路径
    current_script="$(readlink -f "$0")"
    if [ ! -f "$current_script" ]; then
        printf "${RED}错误：无法获取当前脚本路径！${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 删除当前脚本
    printf "\n${YELLOW}正在删除当前脚本...${NC}\n"
    if ! rm -f "$current_script"; then
        printf "${RED}删除当前脚本失败！请检查权限。${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 下载新脚本
    printf "${YELLOW}正在下载最新版本...${NC}\n"
    if ! curl -L "https://raw.githubusercontent.com/qiyueqixi/fnos/refs/heads/main/network.sh" -o "$current_script"; then
        printf "${RED}下载失败！请检查网络连接。${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 设置执行权限
    chmod +x "$current_script"

    printf "${GREEN}脚本已成功升级！${NC}\n"
    printf "${YELLOW}请重新运行脚本以使用新版本。${NC}\n"
    read -p "按回车键退出..."
    exit 0
}

# 主菜单
show_menu() {
    printf "${BLUE}===================================\n"
    printf "        飞牛工具箱安装程序\n"
    printf "===================================${NC}\n"
    printf "1. 将脚本安装到飞牛 (脚本安装后进入root用户后会自动运行！！！)\n"
    printf "2. 卸载脚本\n"
    printf "3. 升级脚本\n"
    printf "0. 退出\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程
while true; do
    show_menu
    read -p "请输入选项数字 (0-3): " choice
    case $choice in
        1) install_script ;;
        2) uninstall_script ;;
        3) upgrade_script ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-3的数字！${NC}\n"; sleep 1 ;;
    esac
done 
