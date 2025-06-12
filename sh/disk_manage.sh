#!/bin/bash

# 功能说明：飞牛磁盘管理工具，支持磁盘使用情况查询、磁盘详细信息查看、SMART信息查看和RAID管理

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

# 添加首次运行标志
FIRST_RUN=true

# 检查依赖项
check_dependencies() {
    if ! command -v smartctl &> /dev/null; then
        printf "${RED}错误：smartctl 未安装，正在自动安装...${NC}\n"
        sudo apt update && sudo apt install smartmontools -y
    fi

    if ! command -v mdadm &> /dev/null; then
        printf "${RED}错误：mdadm 未安装，正在自动安装...${NC}\n"
        sudo apt update && sudo apt install mdadm -y
    fi
}

# 显示磁盘使用情况
show_disk_usage() {
    printf "\n${GREEN}[1] 磁盘使用情况${NC}\n"
    df -h | grep -v "tmpfs" | grep -v "udev" | grep -v "devtmpfs"
    read -p "按回车键返回菜单..."
}

# 显示磁盘详细信息
show_disk_info() {
    printf "\n${GREEN}[2] 磁盘详细信息${NC}\n"
    lsblk -f
    read -p "按回车键返回菜单..."
}

# 显示磁盘SMART信息
show_disk_smart() {
    printf "\n${GREEN}[3] 磁盘SMART信息${NC}\n"
    
    # 获取所有磁盘
    DISKS=($(lsblk -d -o NAME | grep -v "NAME" | grep -v "loop"))
    
    printf "${CYAN}可用的磁盘：${NC}\n"
    for i in "${!DISKS[@]}"; do
        printf "$((i+1)). ${DISKS[$i]}\n"
    done
    
    read -p "请选择要查看的磁盘编号 (1-${#DISKS[@]}): " disk_choice
    if ! [[ "$disk_choice" =~ ^[0-9]+$ ]] || [ "$disk_choice" -lt 1 ] || [ "$disk_choice" -gt ${#DISKS[@]} ]; then
        printf "${RED}错误：无效的选择！${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi
    
    selected_disk="/dev/${DISKS[$((disk_choice-1))]}"
    printf "\n${YELLOW}正在获取 $selected_disk 的SMART信息...${NC}\n"
    sudo smartctl -a "$selected_disk"
    read -p "按回车键返回菜单..."
}

# RAID管理相关函数
check_raid_arrays() {
    printf "\n${GREEN}[1] 检查RAID阵列状态...${NC}\n"
    arrays=$(ls -1 /dev/md[0-9]* 2>/dev/null)
    if [ -z "$arrays" ]; then
        printf "${YELLOW}未检测到RAID阵列${NC}\n"
    else
        for array in $arrays; do
            printf "\n${CYAN}=== 阵列 $array 信息 ===${NC}\n"
            sudo mdadm --detail "$array" | grep -E "State|Raid Level|UUID|Number.*State" -A 10
        done
    fi
    read -p "按回车键返回菜单..."
}

repair_raid_array() {
    printf "\n${GREEN}[2] 修复RAID阵列${NC}\n"
    arrays=$(ls -1 /dev/md[0-9]* 2>/dev/null)
    if [ -z "$arrays" ]; then
        printf "${YELLOW}未检测到RAID阵列${NC}\n"
        read -p "按回车键返回菜单..."
        return
    fi

    printf "${CYAN}可用的RAID阵列：${NC}\n"
    select array in $arrays "返回"; do
        if [ "$array" = "返回" ]; then
            break
        elif [ -n "$array" ]; then
            printf "\n${YELLOW}正在检查阵列 $array 状态...${NC}\n"
            status=$(sudo mdadm --detail "$array" | grep "State" | awk -F': ' '{print $2}')
            if [[ "$status" == *"clean"* ]] || [[ "$status" == *"active"* ]]; then
                printf "${GREEN}阵列状态正常，无需修复${NC}\n"
            else
                printf "${RED}阵列状态异常：$status${NC}\n"
                read -p "是否尝试修复？(y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    printf "\n${YELLOW}可用的磁盘：${NC}\n"
                    disks=$(lsblk -dpno NAME,TYPE | grep 'disk' | awk '{print $1}')
                    select disk in $disks "取消"; do
                        if [ "$disk" = "取消" ]; then
                            break
                        elif [ -n "$disk" ]; then
                            printf "\n${YELLOW}正在尝试修复阵列...${NC}\n"
                            sudo mdadm --stop "$array"
                            sudo mdadm --assemble --force --run "$array" "$disk"
                            if [ $? -eq 0 ]; then
                                printf "${GREEN}阵列修复成功！${NC}\n"
                            else
                                printf "${RED}阵列修复失败！${NC}\n"
                            fi
                            break
                        fi
                    done
                fi
            fi
            break
        fi
    done
    read -p "按回车键返回菜单..."
}

raid_menu() {
    while true; do
        printf "\n${BLUE}=== RAID管理 ===\n"
        printf "1. 检查RAID阵列状态\n2. 修复RAID阵列\n0. 返回主菜单${NC}\n"
        read -p "请输入选项数字 (0-2): " raid_choice
        case $raid_choice in
            1) check_raid_arrays ;;
            2) repair_raid_array ;;
            0) break ;;
            *) printf "${RED}无效选项，请输入0-2的数字！${NC}\n"; sleep 1 ;;
        esac
    done
}

# 主菜单
show_menu() {
    if [ "$FIRST_RUN" = true ]; then
        printf "${YELLOW}"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf " *                                                             * \n"
        printf " *                    欢迎使用飞牛磁盘管理工具                  * \n"
        printf " *                                                             * \n"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf "${NC}"
        FIRST_RUN=false
    fi
    printf "${BLUE}===================================\n"
    printf "        飞牛磁盘管理工具\n"
    printf "===================================${NC}\n"
    printf "1. 查看磁盘使用情况\n2. 查看磁盘详细信息\n3. 查看磁盘SMART信息\n4. RAID管理\n0. 退出\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程
check_dependencies
while true; do
    show_menu
    read -p "请输入选项数字 (0-4): " choice
    case $choice in
        1) show_disk_usage ;;
        2) show_disk_info ;;
        3) show_disk_smart ;;
        4) raid_menu ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-4的数字！${NC}\n"; sleep 1 ;;
    esac
done 