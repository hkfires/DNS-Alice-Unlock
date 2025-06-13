#!/bin/bash

# 一键管理和配置 dnsmasq 脚本
# 请确保使用 sudo 或 root 权限运行此脚本

# 脚本版本和更新时间
VERSION="V_1.3.8"
LAST_UPDATED=$(date +"%Y-%m-%d")

# 检查是否以 root 身份运行6
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31m[错误] 请以 root 权限运行此脚本！\033[0m"
  exit 1
fi

# 检查系统是否为 Debian/Ubuntu
if ! grep -Ei 'debian|ubuntu' /etc/os-release > /dev/null; then
  echo -e "\033[31m[错误] 此脚本仅适用于 Debian 和 Ubuntu 系统！\033[0m"
  exit 1
fi

# 检查 curl 和 jq 是否安装，未安装则自动安装
if ! command -v curl &> /dev/null; then
    echo -e "\033[31mcurl 未安装，正在安装...\033[0m"
    sudo apt-get update && sudo apt-get install -y curl
fi

if ! command -v jq &> /dev/null; then
    echo -e "\033[31mjq 未安装，正在安装...\033[0m"
    sudo apt-get update && sudo apt-get install -y jq
fi

# 指定配置文件的下载地址
CONFIG_FILE="/etc/dnsmasq.conf"
SMARTDNS_CONFIG_FILE="/etc/smartdns/smartdns.conf"
SCRIPT_NAME="dns-unlock.sh"
SCRIPT_PATH="/root/$SCRIPT_NAME"
SYMLINK_PATH="/usr/local/bin/ddns"
AUTHOR="Jimmydada"
MAINTAINER="hKFirEs"

# 检查并创建 ddns 快捷命令（符号链接）
create_symlink() {
  if [ ! -f "$SYMLINK_PATH" ]; then
    echo -e "\033[1;32m首次运行，创建快捷命令 ddns...\033[0m"
    sudo ln -sf "$SCRIPT_PATH" "$SYMLINK_PATH"
    sudo chmod +x "$SYMLINK_PATH"
    echo -e "\033[1;32m快捷命令 ddns 创建成功！\033[0m"
  else
    echo -e "\033[1;33m快捷指令 ddns 快速进入设置\033[0m"
  fi
}

# 获取当前外部IP地址和所属地区
IP_INFO=$(curl -s http://ipinfo.io/json)
IP_ADDRESS=$(echo $IP_INFO | jq -r '.ip')
REGION=$(echo $IP_INFO | jq -r '.region')


# 执行检查和创建符号链接的操作
create_symlink

# 公共函数：检查端口占用并释放
check_and_release_port() {
  local port=$1
  echo -e "\033[1;34m检查端口 $port 的占用情况...\033[0m"

  # 检查端口是否被占用
  if lsof -i :$port | grep -q LISTEN; then
    echo -e "\033[31m端口 $port 被以下进程占用：\033[0m"
    lsof -i :$port

    # 检查是否是由 smartdns 占用
    if lsof -i :$port | grep -q 'smartdns'; then
      echo -e "\033[33msmartdns 服务正在占用端口 $port，尝试停止服务...\033[0m"
      systemctl stop smartdns && systemctl disable smartdns
      if [ $? -eq 0 ]; then
        echo -e "\033[1;32msmartdns 服务已成功停止。\033[0m"
      else
        echo -e "\033[31m[错误] 无法停止 smartdns 服务，请手动检查。\033[0m"
      fi
    fi

    # 检查是否是由 dnsmasq 占用
    if lsof -i :$port | grep -q 'dnsmasq'; then
      echo -e "\033[33mdnsmasq 服务正在占用端口 $port，尝试停止服务...\033[0m"
      systemctl stop dnsmasq && systemctl disable dnsmasq
      if [ $? -eq 0 ]; then
        echo -e "\033[1;32mdnsmasq 服务已成功停止。\033[0m"
      else
        echo -e "\033[31m[错误] 无法停止 dnsmasq 服务，请手动检查。\033[0m"
      fi
    fi

    # 检测并处理 systemd-resolved 服务
    if systemctl is-active --quiet systemd-resolved; then
        echo -e "\033[33m检测到 systemd-resolved 正在运行，占用端口 $port。\033[0m"
        echo -e "\033[33m尝试停止 systemd-resolved 服务...\033[0m"
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        echo -e "\033[1;32m[成功] systemd-resolved 服务已停止并禁用。\033[0m"
    else
        echo -e "\033[1;32msystemd-resolved 服务未运行。\033[0m"
    fi

    # 检测其他未知进程并尝试终止
    echo -e "\033[33m尝试关闭端口 $port 的其他占用进程...\033[0m"
    lsof -i :$port | awk 'NR>1 {print $2}' | xargs -r kill -9
    echo -e "\033[1;32m端口 $port 已释放。\033[0m"
  else
    echo -e "\033[1;32m端口 $port 未被占用。\033[0m"
  fi
}

# 检查并停止占用端口 53 的服务
stop_services_using_port_53() {
    PORT_IN_USE=$(sudo netstat -tuln | grep ':53')
    if [ -n "$PORT_IN_USE" ]; then
        echo -e "\033[1;34m端口 53 已被占用，检查是否为 systemd-resolved...\033[0m"
        
        # 检查是否是 systemd-resolved 占用了端口
        SYSTEMD_RESOLVED=$(ps aux | grep 'systemd-resolved' | grep -v 'grep')
        if [ -n "$SYSTEMD_RESOLVED" ]; then
            echo -e "\033[1;33msystemd-resolved 正在占用端口 53，停止 systemd-resolved 服务...\033[0m"
            sudo systemctl stop systemd-resolved
            sudo systemctl disable systemd-resolved
        fi

        # 检查并停止 dnsmasq 服务
        DNSMASQ=$(ps aux | grep 'dnsmasq' | grep -v 'grep')
        if [ -n "$DNSMASQ" ]; then
            echo -e "\033[1;33mdnsmasq 正在占用端口 53，停止 dnsmasq 服务...\033[0m"
            sudo systemctl stop dnsmasq
            sudo systemctl disable dnsmasq
        fi

  # 强制停止占用端口 53 的所有进程
  echo -e "\033[1;33m发现其他进程占用端口 53，强制停止这些进程...\033[0m"
  PIDS=$(sudo lsof -t -i :53)
  if [ -n "$PIDS" ]; then
    for PID in $PIDS; do
      if [[ "$PID" =~ ^[0-9]+$ ]]; then
        sudo kill -9 "$PID"
        echo -e "\033[1;32m已强制停止进程 PID: $PID\033[0m"
      else
        echo -e "\033[1;31m无效的 PID: $PID，跳过...\033[0m"
      fi
    done
  else
    echo -e "\033[1;32m没有发现占用端口 53 的进程。\033[0m"
  fi
else
  echo -e "\033[1;32m端口 53 未被占用，可以继续配置！\033[0m"
fi
}


# 公共函数：设置 resolv.conf 并锁定
set_and_lock_resolv_conf() {
  local nameserver=$1
  echo -e "\033[1;34m备份 /etc/resolv.conf 文件...\033[0m"
  cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
  echo -e "\033[1;34m删除旧的 /etc/resolv.conf 并创建新文件...\033[0m"
  rm -f /etc/resolv.conf
  echo "nameserver $nameserver" > /etc/resolv.conf
  echo -e "\033[1;34m锁定 /etc/resolv.conf 文件...\033[0m"
  chattr +i /etc/resolv.conf
  echo -e "\033[1;32m操作成功！当前 nameserver 已设置为 $nameserver 并已锁定。\033[0m"
}

# 公共函数 - 更新系统和包管理器
update_system() {
    echo -e "\033[1;33m正在更新系统和包管理器...\033[0m"
    sudo apt-get update -y && sudo apt-get upgrade -y
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32m系统和包管理器已更新至最新版本！\033[0m"
    else
        echo -e "\033[31m更新系统和包管理器失败，请检查网络或权限。\033[0m"
        exit 1
    fi
}

# 公共函数 - 检测并安装必要软件
check_and_install_software() {
    REQUIRED_SOFTWARE=("curl" "lsof")
    for software in "${REQUIRED_SOFTWARE[@]}"; do
        if ! command -v $software &> /dev/null; then
            echo -e "\033[1;33m检测到 $software 未安装，正在安装...\033[0m"
            sudo apt-get install -y $software
            if [ $? -eq 0 ]; then
                echo -e "\033[1;32m$software 安装成功！\033[0m"
            else
                echo -e "\033[31m安装 $software 失败，请检查网络或权限。\033[0m"
                exit 1
            fi
        else
            echo -e "\033[1;32m$software 已安装。\033[0m"
        fi
    done
}

install_smartdns() {
    # 检测系统类型
    SYSTEM_NAME=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    echo -e "\033[1;34m检测到当前系统为：$SYSTEM_NAME\033[0m"

    # 检查 SmartDNS 是否已经安装
    if command -v smartdns >/dev/null 2>&1; then
        echo -e "\033[1;32mSmartDNS 已安装，无需重复安装。\033[0m"
        return
    fi

    if [[ "$SYSTEM_NAME" == "ubuntu" ]]; then
        echo -e "\033[1;34mUbuntu 系统，使用 DEB 包安装 SmartDNS...\033[0m"
        DEB_URL="https://github.com/pymumu/smartdns/releases/download/Release46/smartdns.1.2024.06.12-2222.x86_64-debian-all.deb"
        TEMP_DEB="/tmp/smartdns.deb"

        wget "$DEB_URL" -O "$TEMP_DEB"
        if [ $? -ne 0 ]; then
            echo -e "\033[31m[错误] SmartDNS 安装包下载失败，请检查网络连接！\033[0m"
            exit 1
        fi

        dpkg -i "$TEMP_DEB"
        if [ $? -ne 0 ]; then
            echo -e "\033[31m[警告] 安装依赖失败，尝试修复...\033[0m"
            apt-get -f install -y
        fi

        rm -f "$TEMP_DEB"
    else
        echo -e "\033[1;34m非 Ubuntu 系统，使用 apt 安装 SmartDNS...\033[0m"
        apt update && apt install -y smartdns
        if [ $? -ne 0 ]; then
            echo -e "\033[31m[错误] SmartDNS 安装失败，请检查系统环境！\033[0m"
            exit 1
        fi
    fi

    if command -v smartdns >/dev/null 2>&1; then
        echo -e "\033[1;32mSmartDNS 安装成功！\033[0m"
    else
        echo -e "\033[31m[错误] SmartDNS 安装失败，请检查手动安装！\033[0m"
        exit 1
    fi
}

# IPv4 地址验证
is_valid_ipv4() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# IPv6 地址验证
is_valid_ipv6() {
    local ip=$1
    if [[ "$ip" =~ ^([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}$ || \
          "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,7}:$ || \
          "$ip" =~ ^:(:[0-9a-fA-F]{1,4}){1,7}$ || \
          "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$ || \
          "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$ || \
          "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$ || \
          "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$ || \
          "$ip" =~ ^([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$ || \
          "$ip" =~ ^[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})$ || \
          "$ip" =~ ^(::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4})$ ]]; then
        return 0
    else
        return 1
    fi
}

# --- 从 API 生成配置 ---
generate_config_from_api() {
    local type=$1
    local output_file=$2
    local ipv4_address=$3
    local ipv6_address=$4
    local endpoint="/api/generate_${type}_config"

    # API 服务器的地址
    API_BASE_URL="https://dnsconfig.072899.xyz/"


    echo "正在从 API 获取所有可用域名..."
    DOMAINS=$(curl -s "${API_BASE_URL}/api/get_categories" | jq '[.[] | .minors[] | .domains[]] | unique')

    if [ -z "$DOMAINS" ] || [ "$DOMAINS" == "null" ] || [ "$DOMAINS" == "[]" ]; then
        echo "错误: 无法从 API 获取域名列表，或者列表为空。"
        return 1
    fi
    echo "成功获取所有域名。"

    echo "正在生成 ${type} 配置..."

    JSON_PAYLOAD=$(cat <<EOF
{
    "ipv4": "${ipv4_address}",
    "ipv6": "${ipv6_address}",
    "selected_domains": ${DOMAINS}
}
EOF
)

    response=$(curl -s -X POST "${API_BASE_URL}${endpoint}" \
        -H "Content-Type: application/json" \
        -d "${JSON_PAYLOAD}")

    if echo "${response}" | jq -e '.error' > /dev/null; then
        error_message=$(echo "${response}" | jq -r '.error')
        echo "错误: 生成 ${type} 配置失败: ${error_message}"
        return 1
    fi

    echo "${response}" | jq -r '.config' > "${output_file}"
    echo "成功！${type} 配置已保存到 ${output_file}"
    return 0
}

# 显示标题和备注
echo -e "\033[1;34m======================================\033[0m"
echo -e "\033[1;32m       一键配置 dnsmasq 分流脚本       \033[0m"
echo -e "\033[1;36m       版本：  $VERSION       \033[0m"
echo -e "\033[1;36m       更新时间：$LAST_UPDATED        \033[0m"
echo -e "\033[1;36m       本脚本改编自 $AUTHOR           \033[0m"
echo -e "\033[1;36m       新脚本维护人 $MAINTAINER       \033[0m"
echo -e "\033[1;36m    VPS IP： $IP_ADDRESS  $REGION     \033[0m"
echo -e "\033[1;34m======================================\033[0m"
echo -e "\n"

# 显示主菜单
echo -e "\033[1;33m请选择要执行的操作：\033[0m"
echo -e "\033[1;36m1.\033[0m \033[1;32mdnsmasq 分流配置\033[0m"
echo -e "\033[1;36m2.\033[0m \033[1;32msmartdns 分流配置\033[0m"
echo -e "\033[1;36m3.\033[0m \033[1;32m检测流媒体解锁支持情况\033[0m"
echo -e "\033[1;36m4.\033[0m \033[1;32m删除脚本\033[0m"
echo -e "\033[1;36m5.\033[0m \033[1;32m更新脚本\033[0m"
echo -e "\033[1;36m0.\033[0m \033[1;31m退出\033[0m"
echo -e "\n\033[1;33m请输入数字 (0-5):\033[0m"
read main_choice

case $main_choice in
1)
  # dnsmasq 分流配置子菜单
  while true; do
  echo -e "\033[1;33m请选择要执行的操作：\033[0m"
  echo -e "\033[1;36m1.\033[0m \033[1;32m安装并配置 dnsmasq 分流\033[0m"
  echo -e "\033[1;36m2.\033[0m \033[1;32m卸载 dnsmasq 并恢复默认配置\033[0m"
  echo -e "\033[1;36m3.\033[0m \033[1;32m更新 dnsmasq 配置文件\033[0m"
  echo -e "\033[1;36m4.\033[0m \033[1;32m重启 dnsmasq 服务\033[0m"
  echo -e "\033[1;36m0.\033[0m \033[1;31m退出脚本\033[0m"
  echo -e "\n\033[1;33m请输入数字 (0-4):\033[0m"
  read dnsmasq_choice
  
  case $dnsmasq_choice in
    1)
    # 检测并安装必要软件
    check_and_install_software
    
    # 安装并配置 dnsmasq
    echo "执行安装 dnsmasq 的相关操作..."
    
    # 安装 dnsmasq
    apt update && apt install -y dnsmasq
    if [ $? -ne 0 ]; then
      echo -e "\033[31m[错误] dnsmasq 安装失败，请检查系统环境！\033[0m"
      exit 1
    fi

    # 检查是否成功安装
    if ! command -v dnsmasq >/dev/null 2>&1; then
        echo -e "\033[31m[错误] dnsmasq 安装失败，请检查！\033[0m"
        exit 1
    fi
    echo -e "\033[1;32m[dnsmasq] 安装完成。\033[0m"

    # 检查是否安装 lsof
    if ! command -v lsof >/dev/null 2>&1; then
        echo -e "\033[33m检测到系统未安装 lsof 工具，正在安装...\033[0m"
        apt update && apt install -y lsof
        if ! command -v lsof >/dev/null 2>&1; then
            echo -e "\033[31m[错误] lsof 安装失败，请手动安装后重试！\033[0m"
            exit 1
        fi
        echo -e "\033[1;32m[lsof] 工具安装完成。\033[0m"
    fi

     # 从 API 生成配置文件
    echo -e "\033[1;34m正在从 API 生成 dnsmasq 配置文件...\033[0m"
    while true; do
        read -p "请输入您的解锁 IPv4 地址 (留空则不设置): " unlock_ipv4
        if [ -z "$unlock_ipv4" ] || is_valid_ipv4 "$unlock_ipv4"; then
            break
        else
            echo -e "\033[31m无效的 IPv4 地址格式，请重新输入。\033[0m"
        fi
    done
    while true; do
        read -p "请输入您的解锁 IPv6 地址 (留空则不设置): " unlock_ipv6
        if [ -z "$unlock_ipv6" ] || is_valid_ipv6 "$unlock_ipv6"; then
            break
        else
            echo -e "\033[31m无效的 IPv6 地址格式，请重新输入。\033[0m"
        fi
    done
    
    if [ -z "$unlock_ipv4" ] && [ -z "$unlock_ipv6" ]; then
        echo -e "\033[33m未输入任何 IP 地址，操作取消。\033[0m"
        break
    fi

    generate_config_from_api "dnsmasq" "$CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6"
    if [ $? -ne 0 ]; then
        echo -e "\033[31m[错误] dnsmasq 配置文件生成失败！\033[0m"
        exit 1
    fi

    # 检查端口 53 占用情况
    check_and_release_port 53

    # 备份并更新 /etc/resolv.conf
    set_and_lock_resolv_conf "127.0.0.1"

    # 重启 dnsmasq 服务
    echo -e "\033[1;34m重启 dnsmasq 服务...\033[0m"
    systemctl restart dnsmasq && systemctl enable dnsmasq
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mdnsmasq 服务已成功启动并启用开机自启！\033[0m"
    else
        echo -e "\033[31m[错误] dnsmasq 服务启动失败，请检查配置！\033[0m"
    fi
    ;;
    
  2)
    # 卸载 dnsmasq 并恢复默认配置
    echo -e "\033[1;33m正在卸载 dnsmasq 并恢复系统默认配置...\033[0m"

    # 卸载 dnsmasq
    sudo apt-get purge -y dnsmasq
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mdnsmasq 已成功卸载！\033[0m"
    else
        echo -e "\033[31m卸载 dnsmasq 失败，请检查权限或网络。\033[0m"
        exit 1
    fi

    # 禁用 dnsmasq 服务
    sudo systemctl disable --now dnsmasq &> /dev/null
    echo -e "\033[1;32mdnsmasq 服务已停止并禁用。\033[0m"

    # 删除残留配置文件
    CONFIG_FILE="/etc/dnsmasq.conf"
    if [ -f "$CONFIG_FILE" ]; then
        sudo rm -f "$CONFIG_FILE"
        echo -e "\033[1;32m残留配置文件已清理：$CONFIG_FILE\033[0m"
    fi

    # 恢复系统 DNS 配置
    echo -e "\033[1;33m正在恢复系统 DNS 配置到 8.8.8.8...\033[0m"
    RESOLV_FILE="/etc/resolv.conf"
    if [ -f "$RESOLV_FILE" ]; then
        sudo chattr -i "$RESOLV_FILE" &> /dev/null  # 解除锁定
        echo -e "nameserver 8.8.8.8" | sudo tee "$RESOLV_FILE" > /dev/null
        sudo chattr +i "$RESOLV_FILE" &> /dev/null  # 锁定配置
        echo -e "\033[1;32m系统 DNS 已恢复为 8.8.8.8。\033[0m"
    else
        echo -e "\033[31m未找到 $RESOLV_FILE 文件，请手动检查。\033[0m"
    fi

    # 重启网络服务
    echo -e "\033[1;33m正在重启网络服务...\033[0m"
    sudo systemctl restart systemd-resolved
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32m网络服务已成功重启。\033[0m"
    else
        echo -e "\033[31m重启网络服务失败，请检查日志。\033[0m"
    fi

    echo -e "\033[1;32mdnsmasq 已成功卸载，系统 DNS 恢复完成！\033[0m"
    ;;

3)
    # 更新 dnsmasq 配置文件
    # 更新 dnsmasq 配置文件
    echo -e "\033[1;34m正在从 API 更新 dnsmasq 配置文件...\033[0m"
    while true; do
        read -p "请输入您的解锁 IPv4 地址 (留空则不设置): " unlock_ipv4
        if [ -z "$unlock_ipv4" ] || is_valid_ipv4 "$unlock_ipv4"; then
            break
        else
            echo -e "\033[31m无效的 IPv4 地址格式，请重新输入。\033[0m"
        fi
    done
    while true; do
        read -p "请输入您的解锁 IPv6 地址 (留空则不设置): " unlock_ipv6
        if [ -z "$unlock_ipv6" ] || is_valid_ipv6 "$unlock_ipv6"; then
            break
        else
            echo -e "\033[31m无效的 IPv6 地址格式，请重新输入。\033[0m"
        fi
    done

    if [ -z "$unlock_ipv4" ] && [ -z "$unlock_ipv6" ]; then
        echo -e "\033[33m未输入任何 IP 地址，操作取消。\033[0m"
        break
    fi

    generate_config_from_api "dnsmasq" "$CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6"
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32m配置文件更新成功！\033[0m"
        # 重启 dnsmasq 服务
        echo -e "\033[1;33m重启 dnsmasq 服务...\033[0m"
        systemctl restart dnsmasq
        if [ $? -eq 0 ]; then
            echo -e "\033[1;32mdnsmasq 服务重启成功！\033[0m"
        else
            echo -e "\033[31m重启 dnsmasq 服务失败，请检查日志！\033[0m"
        fi
    else
        echo -e "\033[31m配置文件下载失败，请检查网络连接！\033[0m"
        # 恢复原始配置（如果有备份）
        if [ -f "${CONFIG_FILE}.bak" ]; then
            echo -e "\033[1;33m恢复原始配置文件...\033[0m"
            mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
        fi
    fi
    ;;
  
  4)
    # 重启 dnsmasq 服务
    echo -e "\033[1;34m重启 dnsmasq 服务...\033[0m"
    systemctl restart dnsmasq
    if [ $? -eq 0 ]; then
      echo -e "\033[1;32mdnsmasq 服务已成功重启！\033[0m"
    else
      echo -e "\033[31m[错误] dnsmasq 服务重启失败！\033[0m"
    fi
    ;;

    0)
      break
      ;;
    
    *)
      echo -e "\033[31m无效选择，请重新输入！\033[0m"
      ;;
    esac
  done
  ;;

2)
  # smartdns 分流配置子菜单
  while true; do
  echo -e "\033[1;33m请选择要执行的操作：\033[0m"
  echo -e "\033[1;36m1.\033[0m \033[1;32m安装并配置 smartdns 分流\033[0m"
  echo -e "\033[1;36m2.\033[0m \033[1;32m重启 smartdns 服务\033[0m"
  echo -e "\033[1;36m3.\033[0m \033[1;32m卸载 smartdns 并恢复默认 resolv.conf 配置\033[0m"
  echo -e "\033[1;36m4.\033[0m \033[1;32m更新 smartdns.conf\033[0m"
  echo -e "\033[1;36m0.\033[0m \033[1;31m退出脚本\033[0m"
  echo -e "\n\033[1;33m请输入数字 (0-4):\033[0m"
  read smartdns_choice

  case $smartdns_choice in
  1)
# 检测并安装必要软件
check_and_install_software

# 安装 smartdns
install_smartdns

# 从 API 生成 smartdns 配置文件
echo -e "\033[1;34m正在从 API 生成 smartdns 配置文件...\033[0m"
while true; do
    read -p "请输入您的解锁 IPv4 地址 (留空则不设置): " unlock_ipv4
    if [ -z "$unlock_ipv4" ] || is_valid_ipv4 "$unlock_ipv4"; then
        break
    else
        echo -e "\033[31m无效的 IPv4 地址格式，请重新输入。\033[0m"
    fi
done
while true; do
    read -p "请输入您的解锁 IPv6 地址 (留空则不设置): " unlock_ipv6
    if [ -z "$unlock_ipv6" ] || is_valid_ipv6 "$unlock_ipv6"; then
        break
    else
        echo -e "\033[31m无效的 IPv6 地址格式，请重新输入。\033[0m"
    fi
done

if [ -z "$unlock_ipv4" ] && [ -z "$unlock_ipv6" ]; then
    echo -e "\033[33m未输入任何 IP 地址，操作取消。\033[0m"
    break
fi

generate_config_from_api "smartdns" "$SMARTDNS_CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6"
if [ $? -ne 0 ]; then
    echo -e "\033[31m[错误] smartdns 配置文件生成失败！\033[0m"
    exit 1
fi

# 调用函数来检查和停止端口占用的服务
stop_services_using_port_53

# 检查 /etc/resolv.conf 文件是否被锁定，如果已锁定则解锁
if lsattr /etc/resolv.conf | grep -q 'i'; then
  echo -e "\033[1;33m文件 /etc/resolv.conf 已被锁定，正在解锁...\033[0m"
  chattr -i /etc/resolv.conf
  if [ $? -ne 0 ]; then
    echo -e "\033[31m[错误] 解锁 /etc/resolv.conf 文件失败！\033[0m"
    exit 1
  fi
fi

# 备份 /etc/resolv.conf 文件
echo -e "\033[1;34m备份 /etc/resolv.conf 文件...\033[0m"
cp /etc/resolv.conf /etc/resolv.conf.bak
if [ $? -ne 0 ]; then
  echo -e "\033[31m[错误] /etc/resolv.conf 备份失败！\033[0m"
  exit 1
fi

# 修改 /etc/resolv.conf 中的 nameserver 为 127.0.0.1
echo -e "\033[1;34m修改 /etc/resolv.conf 文件中的 nameserver 为 127.0.0.1...\033[0m"
echo "nameserver 127.0.0.1" > /etc/resolv.conf
if [ $? -ne 0 ]; then
  echo -e "\033[31m[错误] 修改 /etc/resolv.conf 文件失败！\033[0m"
  exit 1
fi

# 锁定 /etc/resolv.conf 文件
echo -e "\033[1;34m锁定 /etc/resolv.conf 文件...\033[0m"
chattr +i /etc/resolv.conf
if [ $? -ne 0 ]; then
  echo -e "\033[31m[错误] 锁定 /etc/resolv.conf 文件失败！\033[0m"
  exit 1
fi

# 启动 smartdns 服务并设置为开机启动
echo -e "\033[1;34m启动 smartdns 并设置为开机启动...\033[0m"
systemctl restart smartdns && systemctl enable smartdns
if [ $? -ne 0 ]; then
  echo -e "\033[31m[错误] smartdns 启动失败！\033[0m"
  exit 1
fi

echo -e "\033[1;32msmartdns 配置已完成，服务已启动并设置为开机启动！\033[0m"
;;

  2)
    # 重启 smartdns 服务
    echo -e "\033[1;34m重启 smartdns 服务...\033[0m"
    systemctl restart smartdns
    if [ $? -eq 0 ]; then
      echo -e "\033[1;32msmartdns 服务已成功重启！\033[0m"
    else
      echo -e "\033[31m[错误] smartdns 服务重启失败！\033[0m"
    fi
    ;;

 3)
    # 卸载 smartdns 并恢复默认 resolv.conf 配置
    echo -e "\033[1;34m正在卸载 smartdns 并恢复默认 resolv.conf 配置...\033[0m"

    # 卸载 smartdns
    apt-get purge -y smartdns
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32msmartdns 已成功卸载！\033[0m"
    else
        echo -e "\033[31m[错误] 卸载 smartdns 失败，请检查权限或网络连接！\033[0m"
        exit 1
    fi

    # 恢复默认 resolv.conf 配置
    RESOLV_FILE="/etc/resolv.conf"
    RESOLV_BAK="/etc/resolv.conf.bak"
    if [ -f "$RESOLV_BAK" ]; then
        echo -e "\033[1;34m正在恢复原始 resolv.conf 配置...\033[0m"
        sudo chattr -i "$RESOLV_FILE" &> /dev/null  # 解锁 resolv.conf 文件
        sudo cp "$RESOLV_BAK" "$RESOLV_FILE"
        sudo chattr +i "$RESOLV_FILE" &> /dev/null  # 锁定配置，防止被覆盖
        echo -e "\033[1;32m原始 resolv.conf 配置已成功恢复！\033[0m"
    else
        echo -e "\033[31m[错误] 找不到备份文件 $RESOLV_BAK，无法恢复默认配置！\033[0m"
        echo -e "\033[1;33m将 resolv.conf 设置为 Google 公共 DNS（8.8.8.8）...\033[0m"
        sudo chattr -i "$RESOLV_FILE" &> /dev/null
        echo -e "nameserver 8.8.8.8" | sudo tee "$RESOLV_FILE" > /dev/null
        sudo chattr +i "$RESOLV_FILE" &> /dev/null
        echo -e "\033[1;32m系统 DNS 已设置为 8.8.8.8。\033[0m"
    fi

    # 重启系统 DNS 服务
    echo -e "\033[1;34m正在重启系统 DNS 服务...\033[0m"
    sudo systemctl restart systemd-resolved
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32m系统 DNS 服务已成功重启！\033[0m"
    else
        echo -e "\033[31m[错误] 系统 DNS 服务重启失败，请检查日志！\033[0m"
    fi

    echo -e "\033[1;32msmartdns 卸载完成，系统 DNS 恢复完成！\033[0m"
    ;;

    4)
      # 更新 smartdns 配置文件
      echo -e "\033[1;34m正在从 API 更新 smartdns 配置文件...\033[0m"
      while true; do
          read -p "请输入您的解锁 IPv4 地址 (留空则不设置): " unlock_ipv4
          if [ -z "$unlock_ipv4" ] || is_valid_ipv4 "$unlock_ipv4"; then
              break
          else
              echo -e "\033[31m无效的 IPv4 地址格式，请重新输入。\033[0m"
          fi
      done
      while true; do
          read -p "请输入您的解锁 IPv6 地址 (留空则不设置): " unlock_ipv6
          if [ -z "$unlock_ipv6" ] || is_valid_ipv6 "$unlock_ipv6"; then
              break
          else
              echo -e "\033[31m无效的 IPv6 地址格式，请重新输入。\033[0m"
          fi
      done
      
      if [ -z "$unlock_ipv4" ] && [ -z "$unlock_ipv6" ]; then
          echo -e "\033[33m未输入任何 IP 地址，操作取消。\033[0m"
          break
      fi
      
      generate_config_from_api "smartdns" "$SMARTDNS_CONFIG_FILE" "$unlock_ipv4" "$unlock_ipv6"
      if [ $? -eq 0 ]; then
          echo -e "\033[1;32m配置文件更新成功！\033[0m"
          # 重启 smartdns 服务
          echo -e "\033[1;33m重启 smartdns 服务...\033[0m"
          systemctl restart smartdns
          if [ $? -eq 0 ]; then
              echo -e "\033[1;32msmartdns 服务重启成功！\033[0m"
          else
              echo -e "\033[31m重启 smartdns 服务失败，请检查日志！\033[0m"
          fi
      else
          echo -e "\033[31m配置文件下载失败，请检查网络连接！\033[0m"
          # 恢复原始配置（如果有备份）
          if [ -f "${CONFIG_FILE}.bak" ]; then
              echo -e "\033[1;33m恢复原始配置文件...\033[0m"
              mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
          fi
      fi
      ;;

    0)
      break
      ;;
    *)
      echo -e "\033[31m无效选择，请重新输入！\033[0m"
      ;;
    esac
  done
  ;;


3)
  # 检测流媒体解锁支持情况
  echo "检测流媒体解锁支持情况..."
  bash <(curl -L -s https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/refs/heads/main/dns-check.sh)
  if [ $? -eq 0 ]; then
    echo "流媒体解锁检测完成！"
  else
    echo "流媒体解锁检测失败，请检查网络连接或脚本 URL！"
  fi
  ;;


4)
  # 删除脚本本地文件
  echo -e "\033[1;34m删除脚本本地文件...\033[0m"
  rm -f $0
  echo -e "\033[1;32m脚本已成功删除！\033[0m"
  ;;

5)
  # 更新脚本
  echo -e "\033[1;34m检查远程脚本版本...\033[0m"
  
  # 获取远程脚本的版本号
  REMOTE_VERSION=$(curl -s https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/refs/heads/main/dns-unlock.sh | grep "VERSION=" | cut -d '"' -f 2)
  
  # 当前脚本的版本号
 CURRENT_VERSION=$(grep 'VERSION=' /root/dns-unlock.sh | cut -d '"' -f 2)
  
  echo -e "\033[1;33m当前版本：$CURRENT_VERSION\033[0m"
  echo -e "\033[1;33m远程版本：$REMOTE_VERSION\033[0m"
  
  # 比较版本号
  if [ "$REMOTE_VERSION" \> "$CURRENT_VERSION" ]; then
    echo -e "\033[1;32m检测到新版本：$REMOTE_VERSION\033[0m"
    echo -e "\033[1;33m正在下载并更新脚本...\033[0m"
    
    # 下载并替换当前脚本
    curl -o /root/dns-unlock.sh https://raw.githubusercontent.com/hkfires/DNS-Alice-Unlock/refs/heads/main/dns-unlock.sh
    if [ $? -eq 0 ]; then
      echo -e "\033[1;32m脚本已成功更新为版本 $REMOTE_VERSION\033[0m"
      
      # 设置脚本可执行权限
      chmod +x /root/dns-unlock.sh

      # 重新执行更新后的脚本
      echo -e "\033[1;34m重新启动脚本...\033[0m"
      /root/dns-unlock.sh
      exit 0
    else
      echo -e "\033[31m[错误] 下载新脚本失败，请检查网络连接！\033[0m"
    fi
  else
    echo -e "\033[1;32m当前已经是最新版本，无需更新！\033[0m"
  fi
  ;;
  
  0)
  echo -e "\033[1;31m退出脚本...\033[0m"
  exit 0
  ;;

*)
  echo -e "\033[31m无效选择，请重新输入！\033[0m"
  ;;
esac
