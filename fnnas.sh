#!/bin/bash

# 功能说明：飞牛系统管理工具主程序

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

# 创建sh目录（如果不存在）
mkdir -p sh

# 检查脚本文件是否存在
check_scripts() {
    local scripts=(
        "network_manage.sh"
        "swap_manage.sh"
        "iommu_manage.sh"
        "qcow_manage.sh"
        "docker_reset.sh"
        "disk_manage.sh"
        "install.sh"
    )
    
    local missing_scripts=()
    
    for script in "${scripts[@]}"; do
        if [ ! -f "sh/$script" ]; then
            missing_scripts+=("$script")
        fi
    done
    
    if [ ${#missing_scripts[@]} -gt 0 ]; then
        printf "${YELLOW}检测到以下脚本文件缺失：${NC}\n"
        for script in "${missing_scripts[@]}"; do
            printf "${RED}- $script${NC}\n"
        done
        return 1
    fi
    
    return 0
}

# 下载所需的脚本文件
download_scripts() {
    local base_url="https://raw.githubusercontent.com/qiyueqixi/fnos/main/sh"
    local scripts=(
        "network_manage.sh"
        "swap_manage.sh"
        "iommu_manage.sh"
        "qcow_manage.sh"
        "docker_reset.sh"
        "disk_manage.sh"
        "install.sh"
    )

    printf "${YELLOW}正在下载必要的脚本文件...${NC}\n"
    
    for script in "${scripts[@]}"; do
        printf "${BLUE}下载 $script...${NC}\n"
        if wget -q "$base_url/$script" -O "sh/$script"; then
            chmod +x "sh/$script"
            printf "${GREEN}成功下载并设置权限: $script${NC}\n"
        else
            printf "${RED}下载失败: $script${NC}\n"
            return 1
        fi
    done
    
    printf "${GREEN}所有脚本下载完成！${NC}\n"
    return 0
}

# 检查并下载缺失的脚本
if ! check_scripts; then
    printf "${YELLOW}正在下载缺失的脚本文件...${NC}\n"
    if ! download_scripts; then
        printf "${RED}脚本下载失败，请检查网络连接或手动下载脚本。${NC}\n"
        exit 1
    fi
fi

# 添加首次运行标志
FIRST_RUN=true

# 检查脚本是否存在
check_script() {
    local script_path="sh/$1"
    if [ ! -f "$script_path" ]; then
        printf "${RED}错误：找不到脚本 $script_path${NC}\n"
        return 1
    fi
    return 0
}

# 执行脚本
run_script() {
    local script_name="$1"
    if check_script "$script_name"; then
        bash "sh/$script_name"
    else
        read -p "按回车键返回菜单..." dummy
    fi
}

# 主菜单
show_menu() {
    if [ "$FIRST_RUN" = true ]; then
        printf "${YELLOW}"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf " *                                                             * \n"
        printf " *                    欢迎使用飞牛系统管理工具                 * \n"
        printf " *                                                             * \n"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf "${NC}"
        FIRST_RUN=false
    fi
    printf "${BLUE} * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
    printf " *                                                             * \n"
    printf " *  1. 网络管理                                               * \n"
    printf " *  2. Swap管理                                               * \n"
    printf " *  3. IOMMU硬件直通管理                                      * \n"
    printf " *  4. QCOW镜像管理                                           * \n"
    printf " *  5. Docker重置                                             * \n"
    printf " *  6. 磁盘管理                                               * \n"
    printf " *  7. 脚本管理                                               * \n"
    printf " *  0. 退出                                                   * \n"
    printf " *                                                             * \n"
    printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * ${NC}\n"
}

# 主流程
while true; do
    show_menu
    read -p "请输入选项数字 (0-7): " choice
    case $choice in
        1) run_script "network_manage.sh" ;;
        2) run_script "swap_manage.sh" ;;
        3) run_script "iommu_manage.sh" ;;
        4) run_script "qcow_manage.sh" ;;
        5) run_script "docker_reset.sh" ;;
        6) run_script "disk_manage.sh" ;;
        7) run_script "install.sh" ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-7的数字！${NC}\n"; sleep 1 ;;
    esac
done
