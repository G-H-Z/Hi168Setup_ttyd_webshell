#!/bin/bash
# Hi168[TTYD-WEBSHELL]自动安装配置脚本
# 作者: G-H-Z
# 版本: 1.0
#-----------------------------
# 格式化配置
#-----------------------------
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'
BOLD='\033[1m'

#-----------------------------
# 全局变量
#-----------------------------
SETUP_VERSION="1.0"
BASE_DIR="/opt"
TTYD_URL="https://d.hi168.com/hi168-tools/ttyd.20241115v2.tar.gz"
WEBSHELL_URL="https://d.hi168.com/hi168-public/webshell.20250415v1.tar.gz"
OUTPUT="ttyd.20241115v2.tar.gz"
OUTPUT2="webshell.20250415v1.tar.gz"
#-----------------------------
# 基础功能函数
#-----------------------------

# 输出带颜色的消息
color_echo() {
    local color="$1"
    shift
    echo -e "${color}${BOLD}$@${RESET}"
}
# 打印分割线
print_separator() {
    local char="${1:-=}"
    local length="${2:-60}"
    printf '%*s\n' "$length" | tr ' ' "$char"
}
# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        color_echo $RED "错误：命令 '$1' 未找到，请先安装。"
        exit 1
    fi
}
# 检查并安装软件包 (自动识别发行版)
install_package() {
    local package_name="$1"
    if ! command -v "$package_name" &> /dev/null; then
        color_echo $YELLOW "正在安装 $package_name ..."
        if [[ -f /etc/debian_version ]]; then
             # Debian/Ubuntu 系
            sudo apt-get update && sudo apt-get install -y "$package_name"
        elif [[ -f /etc/redhat-release ]]; then
            # CentOS/RHEL 系
            sudo yum install -y "$package_name"
        elif [[ -f /etc/fedora-release ]]; then
            # Fedora 系
            sudo dnf install -y "$package_name"
        elif [[ -f /etc/arch-release ]]; then
            # Arch Linux 系
            sudo pacman -S --noconfirm "$package_name"
        else
            color_echo $RED "不支持的 Linux 发行版，请手动安装 $package_name。"
            exit 1
        fi
        color_echo $GREEN "$package_name 安装完成。"
    else
        color_echo $GREEN "$package_name 已安装。"
    fi
}

#安装ttyd工具包
manage_install_ttyd() {

  if ! [[ -f /var/lib/ttyd/ttyd.i686 ]]; then
    download_file "$TTYD_URL" "$OUTPUT"
  fi

  if ! [[ -f /var/lib/ttyd/ttyd.i686 ]]; then
    if ! [[ -f ./ttyd.20241115v2.tar.gz ]]; then
      echo '下载 ttyd 压缩文件失败，请联系管理员。'
      exit 1;
    fi  
    sudo mv ttyd.20241115v2.tar.gz /var/lib

    cd /var/lib
    echo '正在解压ttyd.20241115v2.tar.gz。'
    tar zxvf ttyd.20241115v2.tar.gz
    # rm -f ttyd.20241115v2.tar.gz

    if ! [[ -d /var/lib/ttyd ]]; then
      echo '解压文件失败，请联系管理员。'
      exit 1;
    fi
  fi
  manage_create_ttyd
}

#创建ttyd服务
manage_create_ttyd() {
    local service_file="/etc/systemd/system/ttyd.service"
    if [ -f "$service_file" ]; then
        echo "服务文件 $service_file 已存在。跳过创建。"
        return
    else
      cat <<EOF | tee "$service_file"
[Unit]
Description=ttyd Service
After=network.target

[Service]
ExecStart=/var/lib/ttyd/ttyd.i686 -w /root -p 7149 -W -t fontSize=18 -t 'theme={"background": "black", "foreground":"#17FFEF"}' -t enableTrzsz=true /bin/bash
WorkingDirectory=/var/lib/ttyd
User=root
Group=root
Restart=always
RestartSec=5
StandardOutput=append:/var/lib/ttyd/ttyd.normal.log
StandardError=append:/var/lib/ttyd/ttyd.err.log

[Install]
WantedBy=multi-user.target
EOF
      systemctl daemon-reload
      systemctl enable ttyd.service
    fi

}

#检查ttyd服务
manage_check_ttyd() {
   process_identifier="/var/lib/ttyd/ttyd.i686"
   # 使用 ps 和 grep 检查进程是否存在
   if ps -ef | grep -v grep | grep "$process_identifier" > /dev/null; then
       echo "进程 $process_identifier 正在运行。"
   else
       echo "进程 $process_identifier 未运行。"
   fi
   if cd /var/lib/ttyd; then
        echo "成功切换到 /var/lib/ttyd 目录。"
        # 执行脚本
        if ./start-ttyd.sh; then
            echo "成功执行 start-ttyd.sh 脚本。"
        else
            echo "执行 start-ttyd.sh 脚本时出错。"
        fi
    else
        echo "无法切换到 /var/lib/ttyd 目录。"
    fi
}

manage_setup_webshell() {
   if ! [[ -f /var/lib/webshell/vmshell.log ]]; then
    download_file "$WEBSHELL_URL" "$OUTPUT2"
  fi

  if ! [[ -f /var/lib/webshell/vmshell.log ]]; then
    if ! [[ -f webshell.20250415v1.tar.gz ]]; then
      echo '下载 webshell 压缩文件失败，请联系管理员。'
      exit 1;
    fi  
    mv webshell.20250415v1.tar.gz /var/lib

    cd /var/lib

    tar zxvf webshell.20250415v1.tar.gz
    # rm -f webshell.20250415v1.tar.gz

    if ! [[ -d /var/lib/webshell ]]; then
      echo '解压文件失败，请联系管理员。'
      exit 1;
    fi
  fi
}


# 定义要添加的三条命令
manage_crontab() {
    commands=(
        "@reboot /var/lib/ttyd/start-ttyd.sh 2>&1 &"
        "@reboot /var/lib/ttyd/config-nic.sh 2>&1 &"
        "@reboot /var/lib/webshell/launch-vmshell-daemon.sh"
    )
# 遍历命令数组
    for command in "${commands[@]}"; do
        # 检查 crontab 中是否已存在该命令
        if ! crontab -l 2>/dev/null | grep -qF "$command"; then
            # 如果不存在，则添加该命令到 crontab
            (crontab -l 2>/dev/null; echo "$command") | crontab -
            echo "已将 $command 添加到 crontab 中。"
        else
            echo "$command 已经存在于 crontab 中，无需重复添加。"
        fi
    done
}

manage_dhclient() {
    which dhclient > /var/lib/ttyd/config-nic.sh

    # 检查文件是否成功创建
    if [ $? -ne 0 ]; then
        echo "创建 /var/lib/ttyd/config-nic.sh 文件失败，请检查权限或磁盘空间。"
        exit 1
    fi

    # 设置脚本权限
    chmod +x /var/lib/ttyd/config-nic.sh

    # 检查脚本权限设置是否成功
    if [ $? -ne 0 ]; then
        echo "设置 /var/lib/ttyd/config-nic.sh 文件权限失败，请检查权限设置。"
        exit 1
    fi

    # 检查 dhclient 执行脚本是否正确
    script_content=$(cat /var/lib/ttyd/config-nic.sh)
    if echo "$script_content" | grep -q "/sbin/dhclient"; then
        echo "脚本内容正确，包含 /sbin/dhclient。"
    else
        echo "脚本内容不正确，不包含 /sbin/dhclient。"
    fi
}

# 函数：检查命令是否存在
command_exists() {
    type "$1" &> /dev/null
}

# 函数：确保端口 7149 在防火墙上打开
ensure_port_open() {
    local port=7149

    if command_exists ufw; then
        # 使用 ufw
        echo "检查 ufw 中是否存在端口 $port 的规则..."
        if ! ufw status | grep -q "$port/tcp"; then
            echo "使用 ufw 打开端口 $port..."
            ufw allow $port/tcp
            ufw reload
        else
            echo "ufw 中已存在端口 $port 的规则，无需添加。"
        fi
    elif command_exists firewalld; then
        # 使用 firewalld
        echo "检查 firewalld 中是否存在端口 $port 的规则..."
        if ! firewall-cmd --list-ports | grep -q "$port/tcp"; then
            echo "使用 firewalld 打开端口 $port..."
            firewall-cmd --zone=public --add-port=$port/tcp --permanent
            firewall-cmd --reload
        else
            echo "firewalld 中已存在端口 $port 的规则，无需添加。"
        fi
    elif command_exists iptables; then
        # 使用 iptables
        echo "检查 iptables 中是否存在端口 $port 的规则..."
        if ! iptables -L INPUT -n | grep -q "$port/tcp"; then
            echo "使用 iptables 打开端口 $port..."
            iptables -A INPUT -p tcp --dport $port -j ACCEPT
            iptables-save
        else
            echo "iptables 中已存在端口 $port 的规则，无需添加。"
        fi
    else
        echo "未找到支持的防火墙管理工具。请手动打开端口 $port。"
    fi
}


# 下载文件 (自动选择 wget 或 curl)
download_file() {
    local url="$1"
    local output_file="$2"
    local quiet="${3:-true}"  # 默认静默下载
    local q_flag=""

    if [ "$quiet" = true ]; then
        q_flag="-q"
    fi

    echo "开始下载文件: $url 到 $output_file"

    if command -v wget &> /dev/null; then
        echo "使用 wget 进行下载..."
        if [ "$quiet" = true ]; then
            wget $q_flag --continue "$url" -O "$output_file"
	    echo "wget exit status: $?"
        else
            wget --progress=bar:force:noscroll --continue "$url" -O "$output_file"  # 显示进度条
        fi
        if [ $? -eq 0 ]; then
            echo "使用 wget 下载文件成功: $output_file"
            return 0
        else
            color_echo $RED "使用 wget 下载文件失败: $url"
        fi
    else
        color_echo $YELLOW "wget 不存在，尝试使用 curl 下载..."
    fi

    if command -v curl &> /dev/null; then
        echo "使用 curl 进行下载..."
        curl -sSL "$url" -o "$output_file"
        if [ $? -eq 0 ]; then
            echo "使用 curl 下载文件成功: $output_file"
            return 0
        else
            color_echo $RED "使用 curl 下载文件失败: $url"
            exit 1
        fi
    else
        color_echo $RED "错误：curl 和 wget 都不存在，无法下载文件。"
        exit 1
    fi
}
    


#----------------------------------
# 其余函数 (根据需要修改 URL 和路径)
#----------------------------------

# 切换镜像源
sources_shell() {
    color_echo $YELLOW "开始切换镜像源..."
    color_echo $YELLOW "https://github.com/SuperManito/LinuxMirrors"
    local mirrors_script="/opt/ChangeMirrors.sh"
    local script_url="https://linuxmirrors.cn/main.sh"

    if [ ! -f "$mirrors_script" ]; then
        color_echo $YELLOW "下载 ChangeMirrors.sh 脚本..."
        download_file "$script_url" "$mirrors_script"
    fi

    if [ -f "$mirrors_script" ]; then
        bash "$mirrors_script"
        color_echo $GREEN "镜像源切换完成。"
    else
        color_echo $RED "镜像源切换失败，请检查网络连接或手动配置。"
    fi
}

# 检查并安装必备的相关的工具
check__tools() {
    local tools=("wget" "curl" "tar")
    for tool in "${tools[@]}"; do
        install_package "$tool"
    done
}

# 检查并关闭 UFW 和防火墙
check_ufw_firewalld() {
    # 禁用防火墙
    for service in firewalld iptables; do
        if systemctl is-enabled "$service" &>/dev/null; then
            sudo systemctl stop "$service" &>/dev/null
            sudo systemctl disable "$service" &>/dev/null
            color_echo $YELLOW "防火墙 $service 已禁用."
        fi
    done
    # 禁用 ufw (如果存在)
    if command -v ufw &> /dev/null; then
        sudo ufw disable &> /dev/null
        color_echo $YELLOW "防火墙 ufw 已禁用."
    fi
}

# 检测操作系统版本 (更精确的匹配)
fixed_check_osver() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        color_echo $RED "无法确定发行版。"
        exit 1
    fi

    # 使用 case 语句进行更精确的匹配
    case "$ID$VERSION_ID" in
        centos7)
            os_ver="CentOS Linux 7"
            ;;
        centos8|rhel8|rocky8.10)  # 兼容 CentOS 8 RHEL 8 Rocky 8.10
            os_ver="CentOS/RHEL 8/Rocky 8.10"
            ;;
        ubuntu20.04)
            os_ver="Ubuntu 20.04"
            ;;
        *)
            color_echo $RED "此脚本目前不支持您的系统: $NAME $VERSION_ID"
            exit 1
            ;;
    esac
    color_echo $GREEN "检测到操作系统: $os_ver"
}

# 源码安装 (根据操作系统和网络环境自动选择)
install_for_centos() {
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR" || exit
    # 安装依赖
    color_echo $YELLOW "安装依赖..."
    sudo yum clean all
    sudo yum makecache
    # 安装trzsz
    color_echo $YELLOW "安装trzsz..."
    echo '[trzsz]
    name=Trzsz Repo
    baseurl=https://yum.fury.io/trzsz/
    enabled=1
    gpgcheck=0' | sudo tee /etc/yum.repos.d/trzsz.repo
    sudo yum install -y trzsz
    # 安装dhclient
    color_echo $YELLOW "安装dhclient..."
    sudo yum install -y dhclient
}

install_for_centos8() {
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR" || exit
    # 安装依赖
    color_echo $YELLOW "安装依赖..."
    sudo yum clean all
    sudo yum makecache
    # 安装trzsz
    color_echo $YELLOW "安装trzsz..."
    echo '[trzsz]
    name=Trzsz Repo
    baseurl=https://yum.fury.io/trzsz/
    enabled=1
    gpgcheck=0' | sudo tee /etc/yum.repos.d/trzsz.repo
    sudo yum install -y trzsz
    # 安装dhclient
    color_echo $YELLOW "安装dhclient..."
    sudo yum install -y dhclient
}

# Ubuntu 20.04 源码安装
install_for_ubuntu() {
    mkdir -p "$BASE_DIR"
    cd "$BASE_DIR" || exit
    sudo apt update && sudo apt install software-properties-common
    sudo add-apt-repository ppa:trzsz/ppa && sudo apt update
    sudo apt install trzsz
    # 安装isc-dhcp-client
    color_echo $YELLOW "安装isc-dhcp-client..."
    apt install isc-dhcp-client
}

code_install() {
    fixed_check_osver # 检查操作系统
    case "$os_ver" in
    "CentOS Linux 7")
        check_ufw_firewalld
        install_for_centos
        ;;
    "CentOS/RHEL 8/Rocky 8.10")
        check_ufw_firewalld
        install_for_centos8
        ;;
    "Ubuntu 20.04")
        install_for_ubuntu
        ;;
    *)
        color_echo $RED "不支持的操作系统：$os_ver"
        exit 1
        ;;
    esac
}


# 主菜单
main_menu() {
    clear
    print_separator
    color_echo $BLUE "Hi168[TTYD-WEBSHELL]自动安装配置脚本 (版本 $SETUP_VERSION)"
    print_separator
    echo "首次安装建议先进行换源操作。"
    echo "1) 切换镜像源 (使用LinuxMirrors)"
    echo "2) 安装 (支持 CentOS 7/8, Ubuntu 20.04)"
    echo "3) 退出脚本"
    print_separator
    read -r -p "请输入对应数字: " code_id

    case "$code_id" in
    1)  # 换源
        sources_shell
        main_menu
        ;;
    2)  # 安装TTYD-WEBSHELL
	check__tools
        code_install
	ensure_port_open
	manage_install_ttyd
	systemctl start ttyd.service
	manage_check_ttyd
	manage_setup_webshell
	manage_crontab
	manage_dhclient
	echo "手动添加7149的http服务使用ttyd终端。"
	echo "手动添加7179的http服务使用webshell终端。"
	echo "手动添加7179的http服务使用webshell终端。"
	echo "重启生效。"
        ;;
    3)  # 退出
        exit 0
        ;;
    *)
        color_echo $RED "无效选项，请重新输入。"
        sleep 2
        main_menu  # 返回主菜单
        ;;
    esac
}

# 开始执行
main_menu