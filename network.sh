#!/bin/bash

# 功能说明：交互式网络管理工具，支持网络状态查询、WiFi管理、Swap管理、网络配置管理、OVS网桥管理、IOMMU硬件直通管理

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
    if ! command -v nmcli &> /dev/null; then
        printf "${RED}错误：NetworkManager 未安装，正在自动安装...${NC}\n"
        sudo apt update && sudo apt install network-manager -y
        sudo systemctl start NetworkManager
    fi

    if ! command -v dig &> /dev/null; then
        printf "${RED}错误：dig 工具未安装，正在自动安装 dnsutils...${NC}\n"
        sudo apt install dnsutils -y
    fi

    if ! command -v ip &> /dev/null; then
        printf "${RED}错误：ip 工具未安装，正在自动安装 iproute2...${NC}\n"
        sudo apt install iproute2 -y
    fi
}

# 显示当前网络配置
show_network_config() {
    printf "\n${CYAN}=== 当前网络配置 ===${NC}\n"
    DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
    if [ -z "$DEFAULT_IFACE" ]; then
        printf "${RED}未找到默认网络接口！${NC}\n"
    else
        IP_ADDR=$(ip addr show dev "$DEFAULT_IFACE" | awk '/inet / {print $2}' | cut -d'/' -f1)
        [ -z "$IP_ADDR" ] && IP_ADDR="${RED}无IP地址${NC}"
        GATEWAY=$(ip route | awk '/default/ {print $3}' | head -n1)
        [ -z "$GATEWAY" ] && GATEWAY="${RED}无网关${NC}"
        DNS_SERVERS=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
        [ -z "$DNS_SERVERS" ] && DNS_SERVERS="${RED}无DNS配置${NC}"

        WIFI_INFO=""
        if [[ "$DEFAULT_IFACE" =~ wl* ]]; then
            WIFI_SSID=$(nmcli -t -f active,ssid dev wifi | awk -F':' '$1 == "yes" {print $2}')
            [ -n "$WIFI_SSID" ] && WIFI_INFO="\n${CYAN}WiFi名称  : ${GREEN}$WIFI_SSID${NC}"
        fi

        printf "${CYAN}接口名称: ${GREEN}$DEFAULT_IFACE${NC}\n"
        printf "${CYAN}IP地址  : ${GREEN}$IP_ADDR${NC}\n"
        printf "${CYAN}网关    : ${GREEN}$GATEWAY${NC}\n"
        printf "${CYAN}DNS     : ${GREEN}$DNS_SERVERS${NC}\n"
        printf "$WIFI_INFO\n"
    fi
    printf "${CYAN}===========================${NC}\n"
    read -p "按回车键返回主菜单..."
}

# WiFi管理相关函数
scan_wifi() {
    printf "\n${GREEN}[1] 正在扫描可用WiFi网络...${NC}\n"
    sudo nmcli dev wifi list --rescan yes || printf "${RED}扫描失败！请检查无线网卡是否启用。${NC}\n"
    read -p "按回车键返回菜单..."
}

connect_wifi() {
    printf "\n${GREEN}[2] 连接到WiFi网络${NC}\n"
    read -p "请输入WiFi名称（SSID）: " SSID
    read -sp "请输入WiFi密码: " PASSWORD
    echo
    if sudo nmcli dev wifi connect "$SSID" password "$PASSWORD"; then
        printf "${GREEN}成功连接到 $SSID${NC}\n"
    else
        printf "${RED}连接失败！请检查：\n- SSID和密码是否正确\n- 网络是否在扫描结果中\n- 无线网卡是否启用${NC}\n"
    fi
    read -p "按回车键返回菜单..."
}

check_wifi_driver() {
    printf "\n${GREEN}[3] 正在检查无线网卡驱动兼容性...${NC}\n"
    modules=$(find "/lib/modules/$(uname -r)" -name "*.ko" | grep -iE 'net/wireless|cfg80211|mac80211')
    [ -n "$modules" ] && printf "${GREEN}找到以下无线驱动模块：${NC}\n$modules\n" || printf "${RED}未找到无线驱动模块！可能不支持WiFi功能。${NC}\n"
    read -p "按回车键返回菜单..."
}

wifi_menu() {
    while true; do
        printf "\n${BLUE}=== WiFi管理 ===\n"
        printf "1. 扫描附近的WiFi网络\n2. 连接到WiFi网络\n3. 检查无线驱动兼容性\n0. 返回主菜单${NC}\n"
        read -p "请输入选项数字 (0-3): " wifi_choice
        case $wifi_choice in
            1) scan_wifi ;; 
            2) connect_wifi ;; 
            3) check_wifi_driver ;; 
            0) break ;;
            *) printf "${RED}无效选项，请输入0-3的数字！${NC}\n"; sleep 1 ;;
        esac
    done
}

# Swap管理
disable_swap() {
    printf "\n${GREEN}[1] 正在关闭Swap...${NC}\n"
    sudo swapoff -a && sudo sed -i "s/.*swap.*/#&/" /etc/fstab && sudo rm -f /swapfile
    [ $? -eq 0 ] && printf "${GREEN}Swap已关闭并永久禁用！${NC}\n" || printf "${RED}Swap关闭失败！请检查权限或文件是否存在。${NC}\n"
    read -p "按回车键返回菜单..."
}

swap_menu() {
    while true; do
        printf "\n${BLUE}=== Swap管理 ===\n"
        printf "1. 关闭Swap\n0. 返回主菜单${NC}\n"
        read -p "请输入选项数字 (0-1): " swap_choice
        case $swap_choice in
            1) disable_swap ;; 
            0) break ;;
            *) printf "${RED}无效选项，请输入0-1的数字！${NC}\n"; sleep 1 ;;
        esac
    done
}

# 网络配置管理
set_static_ip() {
    printf "\n${GREEN}[1] 设置静态IP${NC}\n"
    DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
    [ -z "$DEFAULT_IFACE" ] && { printf "${RED}未找到默认网络接口！${NC}\n"; return; }

    read -p "请输入IP地址（例如：192.168.1.100）: " IP_ADDR
    read -p "请输入子网掩码（例如：24）: " PREFIX
    read -p "请输入网关（例如：192.168.1.1）: " GATEWAY
    read -p "请输入DNS服务器（例如：8.8.8.8）: " DNS_SERVER

    if sudo nmcli con mod "$DEFAULT_IFACE" ipv4.addresses "$IP_ADDR/$PREFIX" &&
       sudo nmcli con mod "$DEFAULT_IFACE" ipv4.gateway "$GATEWAY" &&
       sudo nmcli con mod "$DEFAULT_IFACE" ipv4.dns "$DNS_SERVER" &&
       sudo nmcli con mod "$DEFAULT_IFACE" ipv4.method manual &&
       sudo nmcli con down "$DEFAULT_IFACE" && sudo nmcli con up "$DEFAULT_IFACE"; then
        printf "${GREEN}静态IP设置成功！${NC}\n"
    else
        printf "${RED}静态IP设置失败！请检查输入是否正确。${NC}\n"
    fi
    read -p "按回车键返回菜单..."
}

set_dynamic_ip() {
    printf "\n${GREEN}[2] 设置动态IP（DHCP）${NC}\n"
    DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
    [ -z "$DEFAULT_IFACE" ] && { printf "${RED}未找到默认网络接口！${NC}\n"; return; }

    if sudo nmcli con mod "$DEFAULT_IFACE" ipv4.method auto &&
       sudo nmcli con down "$DEFAULT_IFACE" && sudo nmcli con up "$DEFAULT_IFACE"; then
        printf "${GREEN}动态IP设置成功！${NC}\n"
    else
        printf "${RED}动态IP设置失败！${NC}\n"
    fi
    read -p "按回车键返回菜单..."
}

modify_dns() {
    printf "\n${GREEN}[3] 修改DNS服务器${NC}\n"
    DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
    [ -z "$DEFAULT_IFACE" ] && { printf "${RED}未找到默认网络接口！${NC}\n"; return; }

    read -p "请输入DNS服务器（例如：8.8.8.8）: " DNS_SERVER
    if sudo nmcli con mod "$DEFAULT_IFACE" ipv4.dns "$DNS_SERVER" &&
       sudo nmcli con down "$DEFAULT_IFACE" && sudo nmcli con up "$DEFAULT_IFACE"; then
        printf "${GREEN}DNS修改成功！${NC}\n"
    else
        printf "${RED}DNS修改失败！${NC}\n"
    fi
    read -p "按回车键返回菜单..."
}

dns_query() {
    printf "\n${GREEN}[4] DNS查询${NC}\n"
    read -p "请输入要查询的域名（默认：example.com）: " DOMAIN
    DOMAIN=${DOMAIN:-example.com}
    printf "\n${YELLOW}=== 查询结果 ($DOMAIN) ===${NC}\n"
    dig +short "$DOMAIN" || printf "${RED}DNS查询失败！请检查网络连接或域名是否正确。${NC}\n"
    printf "${YELLOW}==============================${NC}\n"
    read -p "按回车键返回菜单..."
}

reset_network_manager() {
    printf "\n${RED}警告：此操作将永久删除所有网络连接配置！${NC}\n"
    read -p "确认继续吗？(y/N): " confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { printf "${YELLOW}操作已取消${NC}\n"; return; }

    printf "\n${GREEN}[1] 清除旧配置...${NC}\n"
    sudo rm -f /etc/NetworkManager/system-connections/*.nmconnection
    sudo systemctl restart NetworkManager

    DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
    [ -z "$DEFAULT_IFACE" ] && { printf "${RED}未找到默认网络接口！${NC}\n"; return; }

    printf "${GREEN}[2] 创建新动态连接...${NC}\n"
    sudo nmcli con add type ethernet ifname "$DEFAULT_IFACE" con-name "dynamic-$DEFAULT_IFACE"
    sudo nmcli con up "dynamic-$DEFAULT_IFACE"

    printf "\n${GREEN}[3] 验证新配置：${NC}\n"
    nmcli con show
    ip addr show "$DEFAULT_IFACE"
    read -p "按回车键返回菜单..."
}

network_config_menu() {
    while true; do
        printf "\n${BLUE}=== 网络配置管理 ===\n"
        printf "1. 设置静态IP\n2. 设置动态IP（DHCP）\n3. 修改DNS服务器\n4. DNS域名查询\n5. 强制重置所有网络配置\n0. 返回主菜单${NC}\n"
        read -p "请输入选项数字 (0-5): " config_choice
        case $config_choice in
            1) set_static_ip ;; 
            2) set_dynamic_ip ;; 
            3) modify_dns ;; 
            4) dns_query ;; 
            5) reset_network_manager ;; 
            0) break ;;
            *) printf "${RED}无效选项，请输入0-5的数字！${NC}\n"; sleep 1 ;;
        esac
    done
}

# OVS 网桥管理相关函数
create_ovs_bridge() {
    printf "\n${GREEN}[1] 创建 OVS 网桥${NC}\n"
    read -p "请输入网桥名称（默认 br0）: " BRIDGE_NAME
    BRIDGE_NAME=${BRIDGE_NAME:-br0}

    if ovs-vsctl br-exists "$BRIDGE_NAME"; then
        printf "${YELLOW}警告：网桥 $BRIDGE_NAME 已存在！${NC}\n"
    else
        ovs-vsctl add-br "$BRIDGE_NAME"
        printf "${GREEN}网桥 $BRIDGE_NAME 创建成功！${NC}\n"
    fi
    read -p "按回车键返回菜单..."
}

add_phys_to_ovs() {
    printf "\n${GREEN}[2] 将物理网卡添加到 OVS 网桥${NC}\n"
    read -p "请输入网桥名称（默认 br0）: " BRIDGE_NAME
    BRIDGE_NAME=${BRIDGE_NAME:-br0}

    if ! ovs-vsctl br-exists "$BRIDGE_NAME"; then
        printf "${RED}错误：网桥 $BRIDGE_NAME 不存在！${NC}\n"
        read -p "按回车键返回菜单..."
        return
    fi

    PHYSICAL_NICS=$(ls /sys/class/net | grep -vE "^lo$|^virbr|^docker|^br-" | grep -v "^$BRIDGE_NAME")
    if [ -z "$PHYSICAL_NICS" ]; then
        printf "${RED}错误：未检测到可用的物理网卡！${NC}\n"
        read -p "按回车键返回菜单..."
        return
    fi

    printf "${CYAN}可用物理网卡：${NC}\n"
    for NIC in $PHYSICAL_NICS; do
        printf "  - $NIC\n"
    done

    read -p "请输入要添加的网卡名称（例如 eth0）: " NIC
    if ! echo "$PHYSICAL_NICS" | grep -q "^$NIC$"; then
        printf "${RED}错误：网卡 $NIC 不存在！${NC}\n"
    else
        ovs-vsctl add-port "$BRIDGE_NAME" "$NIC"
        ip link set "$NIC" up
        printf "${GREEN}网卡 $NIC 已成功添加到网桥 $BRIDGE_NAME！${NC}\n"
    fi
    read -p "按回车键返回菜单..."
}

enable_ovs_stp() {
    printf "\n${GREEN}[3] 启用 OVS 网桥的 STP（生成树协议）${NC}\n"
    read -p "请输入网桥名称（默认 br0）: " BRIDGE_NAME
    BRIDGE_NAME=${BRIDGE_NAME:-br0}

    if ! ovs-vsctl br-exists "$BRIDGE_NAME"; then
        printf "${RED}错误：网桥 $BRIDGE_NAME 不存在！${NC}\n"
        read -p "按回车键返回菜单..."
        return
    fi

    ovs-vsctl set bridge "$BRIDGE_NAME" stp_enable=true
    printf "${GREEN}STP 已在网桥 $BRIDGE_NAME 上启用！${NC}\n"
    read -p "按回车键返回菜单..."
}

# 一键开启OVS桥接
enable_ovs_bridge() {
    printf "\n${GREEN}[4] 一键开启OVS桥接${NC}\n"
    
    # 检查OVS服务是否运行
    if ! systemctl is-active --quiet openvswitch; then
        printf "${YELLOW}正在启动OVS服务...${NC}\n"
        sudo systemctl start openvswitch
        sleep 2
    fi

    # 创建默认网桥
    BRIDGE_NAME="br0"
    if ! ovs-vsctl br-exists "$BRIDGE_NAME"; then
        printf "${YELLOW}创建默认网桥 $BRIDGE_NAME...${NC}\n"
        ovs-vsctl add-br "$BRIDGE_NAME"
    fi

    # 获取默认网络接口
    DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
    if [ -z "$DEFAULT_IFACE" ]; then
        printf "${RED}错误：未找到默认网络接口！${NC}\n"
        return 1
    fi

    # 将物理网卡添加到网桥
    if ! ovs-vsctl port-to-br "$DEFAULT_IFACE" &>/dev/null; then
        printf "${YELLOW}将物理网卡 $DEFAULT_IFACE 添加到网桥...${NC}\n"
        ovs-vsctl add-port "$BRIDGE_NAME" "$DEFAULT_IFACE"
    fi

    # 配置网桥IP
    OLD_IP=$(ip addr show dev "$DEFAULT_IFACE" | awk '/inet / {print $2}')
    if [ -n "$OLD_IP" ]; then
        printf "${YELLOW}配置网桥IP地址...${NC}\n"
        ip addr flush dev "$DEFAULT_IFACE"
        ip addr add "$OLD_IP" dev "$BRIDGE_NAME"
        ip link set "$BRIDGE_NAME" up
    fi

    # 启用STP
    printf "${YELLOW}启用生成树协议...${NC}\n"
    ovs-vsctl set bridge "$BRIDGE_NAME" stp_enable=true

    printf "${GREEN}OVS桥接已成功开启！${NC}\n"
    printf "${CYAN}网桥状态：${NC}\n"
    ovs-vsctl show
    read -p "按回车键返回菜单..."
}

# 一键关闭OVS桥接
disable_ovs_bridge() {
    printf "\n${GREEN}[5] 一键关闭OVS桥接${NC}\n"
    
    BRIDGE_NAME="br0"
    if ! ovs-vsctl br-exists "$BRIDGE_NAME"; then
        printf "${YELLOW}网桥 $BRIDGE_NAME 不存在，无需关闭。${NC}\n"
        return 0
    fi

    # 获取网桥上的所有端口
    PORTS=$(ovs-vsctl list-ports "$BRIDGE_NAME")
    
    # 移除所有端口
    for PORT in $PORTS; do
        printf "${YELLOW}正在移除端口 $PORT...${NC}\n"
        ovs-vsctl del-port "$BRIDGE_NAME" "$PORT"
    done

    # 删除网桥
    printf "${YELLOW}正在删除网桥 $BRIDGE_NAME...${NC}\n"
    ovs-vsctl del-br "$BRIDGE_NAME"

    # 重启网络服务
    printf "${YELLOW}正在重启网络服务...${NC}\n"
    sudo systemctl restart NetworkManager

    printf "${GREEN}OVS桥接已成功关闭！${NC}\n"
    read -p "按回车键返回菜单..."
}

ovs_menu() {
    while true; do
        printf "\n${BLUE}=== OVS 网桥管理 ===\n"
        printf "1. 创建 OVS 网桥\n2. 将物理网卡添加到 OVS 网桥\n3. 启用 STP（生成树协议）\n4. 一键开启OVS桥接\n5. 一键关闭OVS桥接\n0. 返回主菜单${NC}\n"
        read -p "请输入选项数字 (0-5): " ovs_choice
        case $ovs_choice in
            1) create_ovs_bridge ;;
            2) add_phys_to_ovs ;;
            3) enable_ovs_stp ;;
            4) enable_ovs_bridge ;;
            5) disable_ovs_bridge ;;
            0) break ;;
            *) printf "${RED}无效选项，请输入0-5的数字！${NC}\n"; sleep 1 ;;
        esac
    done
}

# IOMMU 硬件直通管理相关函数
check_iommu_status() {
    printf "\n${GREEN}[1] 检测 IOMMU 状态${NC}\n"
    
    # 检查内核参数
    printf "${CYAN}1. 检查内核参数:${NC}\n"
    if grep -q "intel_iommu=on\|amd_iommu=on" /proc/cmdline; then
        printf "${GREEN}IOMMU 已启用 (内核参数)${NC}\n"
        grep -o "intel_iommu=on\|amd_iommu=on\|iommu=pt" /proc/cmdline | sed 's/^/  /'
    else
        printf "${YELLOW}IOMMU 未启用 (内核参数)${NC}\n"
    fi

    # 检查dmesg输出
    printf "\n${CYAN}2. 检查dmesg日志:${NC}\n"
    if sudo dmesg | grep -qi "IOMMU enabled"; then
        printf "${GREEN}IOMMU 已启用 (系统日志)${NC}\n"
        sudo dmesg | grep -i "IOMMU" | head -n 3 | sed 's/^/  /'
    else
        printf "${YELLOW}未找到IOMMU启用日志${NC}\n"
    fi

    # 检查设备分组
    printf "\n${CYAN}3. 检查IOMMU设备分组:${NC}\n"
    if [ -d /sys/kernel/iommu_groups ]; then
        GROUP_COUNT=$(find /sys/kernel/iommu_groups/ -maxdepth 1 -type d | wc -l)
        printf "${GREEN}检测到IOMMU分组 (共 %d 组)${NC}\n" $((GROUP_COUNT-1))
        ls -l /sys/kernel/iommu_groups/ | head -n 5 | sed 's/^/  /'
        printf "${YELLOW}... (仅显示前5组)${NC}\n"
    else
        printf "${RED}未检测到IOMMU设备分组${NC}\n"
    fi

    # 检查CPU支持情况
    printf "\n${CYAN}4. 检查CPU虚拟化支持:${NC}\n"
    if grep -q -E "vmx|svm" /proc/cpuinfo; then
        printf "${GREEN}CPU支持硬件虚拟化${NC}\n"
        grep -m 1 -E "vmx|svm" /proc/cpuinfo | sed 's/^/  /'
    else
        printf "${RED}CPU不支持硬件虚拟化${NC}\n"
    fi

    read -p "按回车键返回菜单..." dummy
}

configure_iommu() {
    printf "\n${GREEN}[2] 配置 IOMMU 硬件直通${NC}\n"

    # 检查当前状态
    if grep -q "intel_iommu=on\|amd_iommu=on" /proc/cmdline; then
        printf "${YELLOW}警告：IOMMU已经启用！${NC}\n"
        read -p "是否继续重新配置？(y/N): " confirm
        [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return
    fi

    # 终极版 CPU 检测（兼容所有格式）
    CPU_VENDOR=$(
        lscpu 2>/dev/null | 
        grep -iE "vendor_id|vendor" | 
        head -n1 | 
        awk -F':[ \t]*' '{print $2}' | 
        tr -d '[:space:]' |
        tr '[:upper:]' '[:lower:]'
    )

    case "$CPU_VENDOR" in
        *genuineintel*|*intel*)
            IOMMU_PARAMS="intel_iommu=on iommu=pt"
            CPU_TYPE="Intel"
            printf "${GREEN}检测到 Intel CPU${NC}\n"
            ;;
        *authenticamd*|*amd*)
            IOMMU_PARAMS="amd_iommu=on iommu=pt"
            CPU_TYPE="AMD"
            printf "${GREEN}检测到 AMD CPU${NC}\n"
            ;;
        *)
            printf "${RED}错误：无法识别 CPU 类型（非 Intel/AMD）！${NC}\n"
            read -p "按回车键返回菜单..." dummy
            return
            ;;
    esac

    # 修改 GRUB 配置
    printf "${YELLOW}正在配置 $CPU_TYPE IOMMU...${NC}\n"
    [ -f /etc/default/grub ] || {
        printf "${RED}错误：找不到 /etc/default/grub 文件！${NC}\n"
        read -p "按回车键返回菜单..." dummy
        return
    }
    
    sudo cp /etc/default/grub /etc/default/grub.bak
    sudo sed -i "s/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX=\"${IOMMU_PARAMS}\"/" /etc/default/grub

    # 更新 GRUB
    printf "${YELLOW}正在更新 GRUB 配置...${NC}\n"
    if command -v update-grub >/dev/null 2>&1; then
        sudo update-grub
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        printf "${RED}错误：找不到 update-grub 或 grub2-mkconfig 命令！${NC}\n"
        read -p "按回车键返回菜单..." dummy
        return
    fi

    # 完成提示
    printf "${GREEN}IOMMU 配置成功！${NC}\n"
    printf "${YELLOW}需要重启系统生效。${NC}\n"
    printf "${GREEN}是否立即重启？(y/N): ${NC}"
    read -r reboot_confirm
    case "$reboot_confirm" in
        [yY]) sudo reboot ;;
        *) printf "${YELLOW}请手动执行 ${CYAN}reboot${YELLOW} 以应用配置！${NC}\n" ;;
    esac
    read -p "按回车键返回菜单..." dummy
}

disable_iommu() {
    printf "\n${GREEN}[3] 关闭 IOMMU 硬件直通${NC}\n"

    # 检查当前状态
    if ! grep -q "intel_iommu=on\|amd_iommu=on" /proc/cmdline; then
        printf "${YELLOW}IOMMU当前未启用，无需关闭${NC}\n"
        read -p "按回车键返回菜单..." dummy
        return
    fi

    # 修改 GRUB 配置
    printf "${YELLOW}正在关闭 IOMMU...${NC}\n"
    [ -f /etc/default/grub ] || {
        printf "${RED}错误：找不到 /etc/default/grub 文件！${NC}\n"
        read -p "按回车键返回菜单..." dummy
        return
    }
    
    sudo cp /etc/default/grub /etc/default/grub.bak
    sudo sed -i "s/\b\(intel_iommu=on\|amd_iommu=on\|iommu=pt\)\b//g" /etc/default/grub

    # 更新 GRUB
    printf "${YELLOW}正在更新 GRUB 配置...${NC}\n"
    if command -v update-grub >/dev/null 2>&1; then
        sudo update-grub
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        printf "${RED}错误：找不到 update-grub 或 grub2-mkconfig 命令！${NC}\n"
        read -p "按回车键返回菜单..." dummy
        return
    fi

    # 完成提示
    printf "${GREEN}IOMMU 已成功关闭！${NC}\n"
    printf "${YELLOW}需要重启系统生效。${NC}\n"
    printf "${GREEN}是否立即重启？(y/N): ${NC}"
    read -r reboot_confirm
    case "$reboot_confirm" in
        [yY]) sudo reboot ;;
        *) printf "${YELLOW}请手动执行 ${CYAN}reboot${YELLOW} 以应用配置！${NC}\n" ;;
    esac
    read -p "按回车键返回菜单..." dummy
}

iommu_menu() {
    while true; do
        printf "\n${BLUE}=== IOMMU 硬件直通管理 ===\n"
        printf "1. 检测 IOMMU 状态\n2. 启用 IOMMU 硬件直通\n3. 关闭 IOMMU 硬件直通\n0. 返回主菜单${NC}\n"
        read -p "请输入选项数字 (0-3): " iommu_choice
        case $iommu_choice in
            1) check_iommu_status ;;
            2) configure_iommu ;; 
            3) disable_iommu ;; 
            0) break ;;
            *) printf "${RED}无效选项，请输入0-3的数字！${NC}\n"; sleep 1 ;;
        esac
    done
}

# 镜像转换功能
convert_img_to_qcow2() {
    printf "\n${GREEN}[1] img镜像转qcow2镜像${NC}\n"
    
    # 检查qemu-img是否安装
    if ! command -v qemu-img &> /dev/null; then
        printf "${RED}错误：qemu-img 未安装，正在自动安装...${NC}\n"
        sudo apt update && sudo apt install qemu-utils -y
    fi

    # 获取当前目录下的所有img文件
    IMG_FILES=($(ls *.img 2>/dev/null))
    
    # 显示可用的img文件
    if [ ${#IMG_FILES[@]} -gt 0 ]; then
        printf "\n${CYAN}当前目录下的镜像文件：${NC}\n"
        for i in "${!IMG_FILES[@]}"; do
            printf "$((i+1)). ${IMG_FILES[$i]}\n"
        done
        printf "0. 手动输入镜像路径\n"
        
        # 选择要转换的文件
        read -p "请选择要转换的文件编号 (0-${#IMG_FILES[@]}): " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt ${#IMG_FILES[@]} ]; then
            printf "${RED}错误：无效的选择！${NC}\n"
            read -p "按回车键返回菜单..."
            return 1
        fi

        if [ "$choice" -eq 0 ]; then
            read -p "请输入源镜像文件路径: " selected_file
        else
            selected_file="${IMG_FILES[$((choice-1))]}"
        fi
    else
        read -p "请输入源镜像文件路径: " selected_file
    fi

    # 检查源文件是否存在
    if [ ! -f "$selected_file" ]; then
        printf "${RED}错误：源镜像文件不存在！${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 获取输出文件名
    default_output="${selected_file%.img}.qcow2"
    read -p "请输入目标镜像文件路径 (默认: $default_output): " output_file
    output_file=${output_file:-$default_output}

    # 检查输出文件是否已存在
    if [ -f "$output_file" ]; then
        printf "${YELLOW}警告：$output_file 已存在！${NC}\n"
        read -p "是否覆盖？(y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            printf "${YELLOW}操作已取消${NC}\n"
            read -p "按回车键返回菜单..."
            return 1
        fi
    fi

    # 执行转换
    printf "\n${YELLOW}正在转换 $selected_file 到 $output_file...${NC}\n"
    if qemu-img convert -f raw -O qcow2 "$selected_file" "$output_file"; then
        printf "${GREEN}转换成功！${NC}\n"
        # 显示转换后的文件信息
        printf "\n${CYAN}转换后的文件信息：${NC}\n"
        qemu-img info "$output_file"
    else
        printf "${RED}转换失败！${NC}\n"
    fi
    read -p "按回车键返回菜单..."
}

# 删除Docker数据目录
delete_docker_data() {
    printf "\n${GREEN}[2] 删除Docker数据目录${NC}\n"
    
    # 检查是否存在多个存储空间，排除 /vol00、/vol01、/vol02 等
    VOL_DIRS=($(ls -d /vol[0-9]* 2>/dev/null | grep -vE "^/vol0[0-9]$"))
    
    if [ ${#VOL_DIRS[@]} -eq 0 ]; then
        printf "${RED}错误：未找到任何存储空间目录！${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 显示可用的存储空间
    printf "\n${CYAN}可用的存储空间：${NC}\n"
    for i in "${!VOL_DIRS[@]}"; do
        # 从路径中提取数字
        vol_num=$(echo "${VOL_DIRS[$i]}" | grep -o '[0-9]\+$')
        printf "$((i+1)). 存储空间$vol_num\n"
    done

    # 选择存储空间
    read -p "请选择要操作的存储空间编号 (1-${#VOL_DIRS[@]}): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#VOL_DIRS[@]} ]; then
        printf "${RED}错误：无效的选择！${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    selected_vol="${VOL_DIRS[$((choice-1))]}"
    docker_dir="$selected_vol/1000/docker"

    # 检查Docker目录是否存在
    if [ ! -d "$docker_dir" ]; then
        printf "${YELLOW}警告：在存储空间${selected_vol##*vol} 中未找到Docker数据目录！${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 显示警告信息
    printf "\n${RED}警告：此操作将删除以下内容：${NC}\n"
    printf "1. 所有Docker容器配置\n"
    printf "2. 所有Docker镜像\n"
    printf "3. 所有Docker网络配置\n"
    printf "4. 所有Docker卷数据\n"
    printf "5. 所有Docker服务配置\n"
    printf "\n${RED}此操作不可恢复！${NC}\n"
    printf "${RED}此操作不可恢复！${NC}\n"
    printf "${RED}此操作不可恢复！${NC}\n"
    
    read -p "是否继续删除存储空间${selected_vol##*vol}中的Docker数据目录？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf "${YELLOW}操作已取消${NC}\n"
        read -p "按回车键返回菜单..."
        return 1
    fi

    # 执行删除
    printf "\n${YELLOW}正在删除Docker数据目录...${NC}\n"
    if sudo rm -rf "$docker_dir"; then
        printf "${GREEN}Docker数据目录已成功删除！${NC}\n"
        printf "${YELLOW}请重启Docker服务以应用更改。${NC}\n"
    else
        printf "${RED}删除失败！请检查权限或手动删除。${NC}\n"
    fi
    read -p "按回车键返回菜单..."
}

# 镜像管理菜单
img_menu() {
    while true; do
        printf "\n${BLUE}=== 镜像管理 ===\n"
        printf "1. img镜像转qcow2镜像\n0. 返回主菜单${NC}\n"
        read -p "请输入选项数字 (0-1): " img_choice
        case $img_choice in
            1) convert_img_to_qcow2 ;;
            0) break ;;
            *) printf "${RED}无效选项，请输入0-1的数字！${NC}\n"; sleep 1 ;;
        esac
    done
}

# 安装管理菜单
install_menu() {
    while true; do
        printf "\n${BLUE}=== 安装管理 ===\n"
        printf "1. 安装脚本到系统\n2. 卸载脚本\n0. 返回主菜单${NC}\n"
        read -p "请输入选项数字 (0-2): " install_choice
        case $install_choice in
            1) install_script ;;
            2) uninstall_script ;;
            0) break ;;
            *) printf "${RED}无效选项，请输入0-2的数字！${NC}\n"; sleep 1 ;;
        esac
    done
}

# 将脚本安装到系统
install_script() {
    printf "\n${GREEN}[9] 将脚本安装到飞牛${NC}\n"
    
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
    printf "\n${GREEN}[10] 卸载脚本${NC}\n"
    
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
    if [ "$FIRST_RUN" = true ]; then
        printf "${YELLOW}"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf " *                             _ooOoo_                         * \n"
        printf " *                            o8888888o                        * \n"
        printf " *                            88\" . \"88                        * \n"
        printf " *                            (| -_- |)                        * \n"
        printf " *                            O\\  =  /O                        * \n"
        printf " *                         ____/\`---'\\____                     * \n"
        printf " *                       .'  \\\\|     |//  \`.                   * \n"
        printf " *                      /  \\\\|||  :  |||//  \\                  * \n"
        printf " *                     /  _||||| -:- |||||-  \\                 * \n"
        printf " *                     |   | \\\\\\  -  /// |   |                 * \n"
        printf " *                     | \\_|  ''\\---/''  |   |                 * \n"
        printf " *                     \\  .-\\__  \`-\`  ___/-. /                 * \n"
        printf " *                   ___\\\\. .'  /--.--\\  \`. . __                * \n"
        printf " *                .\"\" '<  \`.___\\_<|>_/___.'  >'\"\".             * \n"
        printf " *               | | :  \`- \\\`.;\`\\ _ /\`;.\`/ - \` : | |           * \n"
        printf " *               \\  \\ \`-.   \\_ __\\ /__ _/   .-\` /  /           * \n"
        printf " *          ======\`-.____\`-.\\___\\_____/___.-\`____.-'======      * \n"
        printf " *                             \`=---='                         * \n"
        printf " *          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^      * \n"
        printf " *                          佛祖保佑                            * \n"
        printf " *              佛曰:                                          * \n"
        printf " *                        所有牛友的NAS！                       * \n"
        printf " *                   硬件不损坏，系统不崩溃！                    * \n"
        printf " *                   硬盘不报错，数据不丢失！                    * \n"
        printf " *                                                             * \n"
        printf " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
        printf "${NC}"
        FIRST_RUN=false
    fi
    printf "${BLUE}===================================\n"
    printf "        飞牛工具箱\n"
    printf "===================================${NC}\n"
    printf "1. 当前网络配置查询\n2. WiFi管理\n3. Swap管理\n4. 网络配置管理\n5. OVS网桥管理\n6. IOMMU硬件直通\n7. 镜像管理\n8. 重置docker数据为出厂\n9. 将脚本安装到飞牛\n10. 升级脚本\n0. 退出\n"
    printf "${BLUE}===================================${NC}\n"
}

# 主流程
check_dependencies
while true; do
    show_menu
    read -p "请输入选项数字 (0-10): " choice
    case $choice in
        1) show_network_config ;; 
        2) wifi_menu ;; 
        3) swap_menu ;; 
        4) network_config_menu ;; 
        5) ovs_menu ;; 
        6) iommu_menu ;; 
        7) img_menu ;;
        8) delete_docker_data ;;
        9) install_menu ;;
        10) upgrade_script ;;
        0) printf "${GREEN}已退出菜单。${NC}\n"; exit 0 ;;
        *) printf "${RED}无效选项，请输入0-10的数字！${NC}\n"; sleep 1 ;;
    esac
done
