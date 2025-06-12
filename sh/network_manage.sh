#!/bin/bash

# 功能说明：网络管理工具
# 支持功能：
# 1. 查看当前网络配置
# 2. WiFi管理
# 3. 网络配置管理
# 4. OVS桥接管理
# 5. WOL网络唤醒

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

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    # 检查必要的命令
    for cmd in ip nmcli iwconfig iw; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        printf "${RED}错误：缺少以下依赖：${NC}\n"
        printf "${YELLOW}%s${NC}\n" "${missing_deps[@]}"
        printf "\n${YELLOW}请选择安装方式：${NC}\n"
        printf "1. 自动安装（推荐）\n"
        printf "2. 手动安装\n"
        printf "3. 跳过安装（部分功能可能不可用）\n"
        printf "0. 返回主菜单\n"
        read -p "请输入选项数字 (0-3): " install_choice
        
        case $install_choice in
            1)
                printf "${BLUE}正在安装依赖...${NC}\n"
                if command -v apt-get &> /dev/null; then
                    apt-get update
                    apt-get install -y network-manager wireless-tools
                elif command -v yum &> /dev/null; then
                    yum install -y NetworkManager wireless-tools
                else
                    printf "${RED}错误：不支持的包管理器！${NC}\n"
                    return 1
                fi
                printf "${GREEN}依赖安装完成！${NC}\n"
                return 0
                ;;
            2)
                printf "${YELLOW}请手动安装以下包：${NC}\n"
                printf "Ubuntu/Debian: sudo apt-get install network-manager wireless-tools\n"
                printf "CentOS/RHEL: sudo yum install NetworkManager wireless-tools\n"
                return 1
                ;;
            3)
                printf "${YELLOW}警告：部分功能可能不可用！${NC}\n"
                return 0
                ;;
            0)
                return 1
                ;;
            *)
                printf "${RED}无效选项！${NC}\n"
                return 1
                ;;
        esac
    fi
    return 0
}

# 显示当前网络配置
show_network_config() {
    printf "${BLUE}当前网络配置：${NC}\n"
    
    # 显示网络接口信息（简化版）
    printf "${YELLOW}网络接口信息：${NC}\n"
    ip -o addr show | grep -v "lo" | while read -r line; do
        interface=$(echo "$line" | awk '{print $2}')
        mac=$(echo "$line" | awk '{print $17}')
        
        # 获取IPv4地址
        ipv4=$(ip -4 addr show "$interface" | grep "inet" | awk '{print $2}')
        if [ -z "$ipv4" ]; then
            ipv4="无IPv4地址"
        fi
        
        # 获取IPv6地址（合并多个IPv6地址到一行）
        ipv6=$(ip -6 addr show "$interface" | grep "inet6" | grep "global" | awk '{print $2}' | tr '\n' ' ')
        if [ -z "$ipv6" ]; then
            ipv6="无IPv6地址"
        fi
        
        # 显示接口信息，每个地址单独一行
        printf "接口: %s\n" "$interface"
        printf "IPv4: %s\n" "$ipv4"
        printf "IPv6: %s\n" "$ipv6"
        printf "MAC:  %s\n" "$mac"
        printf "\n"
    done
    
    # 显示路由表信息（简化版）
    printf "${YELLOW}路由表信息：${NC}\n"
    ip route show | grep -v "docker" | while read -r line; do
        if [[ $line == default* ]]; then
            gateway=$(echo "$line" | awk '{print $3}')
            dev=$(echo "$line" | awk '{print $5}')
            printf "默认网关: %-15s 接口: %s\n" "$gateway" "$dev"
        elif [[ $line == *"dev"* ]]; then
            network=$(echo "$line" | awk '{print $1}')
            dev=$(echo "$line" | awk '{print $3}')
            printf "网络: %-20s 接口: %s\n" "$network" "$dev"
        fi
    done
    
    # 显示DNS配置（简化版）
    printf "\n${YELLOW}DNS配置：${NC}\n"
    grep "nameserver" /etc/resolv.conf | awk '{print $2}' | while read -r dns; do
        if [[ $dns != *"%"* ]]; then
            printf "DNS服务器: %s\n" "$dns"
        fi
    done
}

# WiFi管理
wifi_menu() {
    while true; do
        printf "${BLUE}===================================\n"
        printf "            WiFi管理\n"
        printf "===================================${NC}\n"
        printf "1. 扫描WiFi网络\n"
        printf "2. 连接WiFi网络\n"
        printf "3. 检查WiFi驱动\n"
        printf "0. 返回主菜单\n"
        printf "${BLUE}===================================${NC}\n"
        read -p "请输入选项数字 (0-3): " choice
        case $choice in
            1) 
                printf "${YELLOW}正在扫描WiFi网络...${NC}\n"
                nmcli device wifi list
                ;;
            2)
                read -p "请输入WiFi名称: " ssid
                read -sp "请输入WiFi密码: " password
                echo
                printf "${YELLOW}正在连接WiFi...${NC}\n"
                nmcli device wifi connect "$ssid" password "$password"
                ;;
            3)
                printf "${YELLOW}WiFi驱动信息：${NC}\n"
                lspci | grep -i network
                iwconfig
                ;;
            0) return ;;
            *) printf "${RED}无效选项，请输入0-3的数字！${NC}\n"; sleep 1 ;;
        esac
        read -p "按回车键继续..." dummy
    done
}

# 网络配置管理
network_config_menu() {
    while true; do
        printf "${BLUE}===================================\n"
        printf "         网络配置管理\n"
        printf "===================================${NC}\n"
        printf "1. 设置静态IP\n"
        printf "2. 设置动态IP\n"
        printf "3. 修改DNS\n"
        printf "4. 查看DNS配置\n"
        printf "0. 返回主菜单\n"
        printf "${BLUE}===================================${NC}\n"
        read -p "请输入选项数字 (0-4): " choice
        case $choice in
            1)
                read -p "请输入网络接口名称: " interface
                read -p "请输入IP地址: " ip
                read -p "请输入子网掩码: " netmask
                read -p "请输入网关: " gateway
                nmcli connection modify "$interface" ipv4.method manual ipv4.addresses "$ip/$netmask" ipv4.gateway "$gateway"
                nmcli connection up "$interface"
                ;;
            2)
                read -p "请输入网络接口名称: " interface
                nmcli connection modify "$interface" ipv4.method auto
                nmcli connection up "$interface"
                ;;
            3)
                read -p "请输入DNS服务器地址: " dns
                nmcli connection modify "$interface" ipv4.dns "$dns"
                nmcli connection up "$interface"
                ;;
            4)
                cat /etc/resolv.conf
                ;;
            0) return ;;
            *) printf "${RED}无效选项，请输入0-4的数字！${NC}\n"; sleep 1 ;;
        esac
        read -p "按回车键继续..." dummy
    done
}

# OVS桥接管理
ovs_bridge_menu() {
    while true; do
        printf "${BLUE}===================================\n"
        printf "          OVS桥接管理\n"
        printf "===================================${NC}\n"
        printf "1. 启用OVS桥接\n"
        printf "2. 禁用OVS桥接\n"
        printf "0. 返回主菜单\n"
        printf "${BLUE}===================================${NC}\n"
        read -p "请输入选项数字 (0-2): " choice
        case $choice in
            1)
                if ! command -v ovs-vsctl &> /dev/null; then
                    printf "${RED}错误：未安装Open vSwitch！${NC}\n"
                    read -p "按回车键继续..." dummy
                    continue
                fi
                read -p "请输入桥接名称: " bridge_name
                read -p "请输入要添加的接口名称: " interface
                ovs-vsctl add-br "$bridge_name"
                ovs-vsctl add-port "$bridge_name" "$interface"
                ;;
            2)
                if ! command -v ovs-vsctl &> /dev/null; then
                    printf "${RED}错误：未安装Open vSwitch！${NC}\n"
                    read -p "按回车键继续..." dummy
                    continue
                fi
                read -p "请输入桥接名称: " bridge_name
                ovs-vsctl del-br "$bridge_name"
                ;;
            0) return ;;
            *) printf "${RED}无效选项，请输入0-2的数字！${NC}\n"; sleep 1 ;;
        esac
        read -p "按回车键继续..." dummy
    done
}

# WOL网络唤醒管理
wol_menu() {
    while true; do
        printf "${BLUE}===================================\n"
        printf "          WOL网络唤醒管理\n"
        printf "===================================${NC}\n"
        printf "1. 启用WOL\n"
        printf "2. 禁用WOL\n"
        printf "3. 查看WOL状态\n"
        printf "4. 发送WOL唤醒包\n"
        printf "0. 返回主菜单\n"
        printf "${BLUE}===================================${NC}\n"
        read -p "请输入选项数字 (0-4): " choice
        case $choice in
            1)
                # 获取网络接口列表
                interfaces=$(ls /sys/class/net | grep -E '^(ens|enp|eth|em)')
                if [ -z "$interfaces" ]; then
                    printf "${RED}错误：未找到物理网络接口！${NC}\n"
                    return 1
                fi
                
                printf "${YELLOW}可用的网络接口：${NC}\n"
                printf "${CYAN}请选择要启用WOL的网络接口（输入数字）：${NC}\n"
                select interface in $interfaces; do
                    if [ -n "$interface" ]; then
                        printf "${YELLOW}正在为接口 $interface 启用WOL...${NC}\n"
                        ethtool -s $interface wol g
                        if [ $? -eq 0 ]; then
                            printf "${GREEN}WOL已启用！${NC}\n"
                            # 添加到crontab
                            (crontab -l 2>/dev/null | grep -v "ethtool -s $interface wol" ; echo "@reboot /sbin/ethtool -s $interface wol g") | crontab -
                        else
                            printf "${RED}启用WOL失败！${NC}\n"
                        fi
                        break
                    else
                        printf "${RED}无效选择！${NC}\n"
                    fi
                done
                ;;
            2)
                # 获取网络接口列表
                interfaces=$(ls /sys/class/net | grep -E '^(ens|enp|eth|em)')
                if [ -z "$interfaces" ]; then
                    printf "${RED}错误：未找到物理网络接口！${NC}\n"
                    return 1
                fi
                
                printf "${YELLOW}可用的网络接口：${NC}\n"
                printf "${CYAN}请选择要禁用WOL的网络接口（输入数字）：${NC}\n"
                select interface in $interfaces; do
                    if [ -n "$interface" ]; then
                        printf "${YELLOW}正在为接口 $interface 禁用WOL...${NC}\n"
                        ethtool -s $interface wol d
                        if [ $? -eq 0 ]; then
                            printf "${GREEN}WOL已禁用！${NC}\n"
                            # 从crontab中移除
                            (crontab -l 2>/dev/null | grep -v "ethtool -s $interface wol") | crontab -
                            # 配置NetworkManager防止自动恢复
                            nm_dir="/etc/NetworkManager/conf.d"
                            nm_file="$nm_dir/90-disable-wol-$interface.conf"
                            mkdir -p $nm_dir
                            echo -e "[connection]\nmatch-device=interface-name:$interface\nethernet.wake-on-lan=0" | sudo tee $nm_file > /dev/null
                            systemctl restart NetworkManager
                        else
                            printf "${RED}禁用WOL失败！${NC}\n"
                        fi
                        break
                    else
                        printf "${RED}无效选择！${NC}\n"
                    fi
                done
                ;;
            3)
                # 获取网络接口列表
                interfaces=$(ls /sys/class/net | grep -E '^(ens|enp|eth|em)')
                if [ -z "$interfaces" ]; then
                    printf "${RED}错误：未找到物理网络接口！${NC}\n"
                    return 1
                fi
                
                printf "${YELLOW}网络接口WOL状态：${NC}\n"
                for interface in $interfaces; do
                    status=$(ethtool $interface | grep "Wake-on:" | awk '{print $2}')
                    printf "接口: %-10s WOL状态: %s\n" "$interface" "$status"
                done
                ;;
            4)
                if [ ! -f "/root/wol.txt" ]; then
                    printf "${YELLOW}未找到WOL设备配置文件，是否创建？(y/n): ${NC}"
                    read create_choice
                    if [ "$create_choice" = "y" ] || [ "$create_choice" = "Y" ]; then
                        touch /root/wol.txt
                        printf "${GREEN}已创建WOL设备配置文件。${NC}\n"
                    else
                        return 0
                    fi
                fi
                
                printf "${YELLOW}已保存的WOL设备：${NC}\n"
                cat /root/wol.txt
                printf "\n${YELLOW}请选择操作：${NC}\n"
                printf "1. 添加新设备\n"
                printf "2. 发送唤醒包\n"
                printf "0. 返回\n"
                read -p "请输入选项数字 (0-2): " sub_choice
                
                case $sub_choice in
                    1)
                        read -p "请输入设备名称: " name
                        read -p "请输入MAC地址: " mac
                        if [[ $mac =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
                            echo "$name $mac" >> /root/wol.txt
                            printf "${GREEN}设备已添加！${NC}\n"
                        else
                            printf "${RED}错误：无效的MAC地址格式！${NC}\n"
                        fi
                        ;;
                    2)
                        read -p "请输入要唤醒的设备MAC地址: " mac
                        if [[ $mac =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
                            printf "${YELLOW}正在发送WOL唤醒包...${NC}\n"
                            etherwake -i eth0 "$mac"
                            printf "${GREEN}WOL唤醒包已发送！${NC}\n"
                        else
                            printf "${RED}错误：无效的MAC地址格式！${NC}\n"
                        fi
                        ;;
                    0) return ;;
                    *) printf "${RED}无效选项！${NC}\n" ;;
                esac
                ;;
            0) return ;;
            *) printf "${RED}无效选项，请输入0-4的数字！${NC}\n"; sleep 1 ;;
        esac
        read -p "按回车键继续..." dummy
    done
}

# 主菜单
show_menu() {
    if [ "$FIRST_RUN" = true ]; then
        printf "${YELLOW}"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf " *                                                             * \n"
        printf " *                    欢迎使用网络管理工具                     * \n"
        printf " *                                                             * \n"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf "${NC}"
        FIRST_RUN=false
    fi
    printf "${BLUE}===================================\n"
    printf "        网络管理工具\n"
    printf "===================================${NC}\n"
    printf "1. 查看当前网络配置\n"
    printf "2. WiFi管理\n"
    printf "3. 网络配置管理\n"
    printf "4. OVS桥接管理\n"
    printf "5. WOL网络唤醒\n"
    printf "0. 退出\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程
if ! check_dependencies; then
    read -p "按回车键返回主菜单..." dummy
    exit 1
fi

while true; do
    show_menu
    read -p "请输入选项数字 (0-5): " choice
    case $choice in
        1) show_network_config; read -p "按回车键继续..." dummy ;;
        2) wifi_menu ;;
        3) network_config_menu ;;
        4) ovs_bridge_menu ;;
        5) wol_menu ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-5的数字！${NC}\n"; sleep 1 ;;
    esac
done 