#!/bin/bash

export LINUX_USERNAME=new-linux-username
export LINUX_PASSWORD=new-linux-password
export needMapGithubIP=false
export isAliyunECS=true
export needConfigGitConfig=false

export STARTUP_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

# 当前只处理Linux系统
cygwin=false
darwin=false
msys=false
linux=false
case "`uname`" in
  CYGWIN* )
    echo 'OS:cygwin'
    exit
    ;;
  Darwin* )
    darwin=true
    echo 'OS:macOS'
    exit
    ;;
  MINGW* )
    msys=true
    echo 'OS:Linux'
    exit
    ;;
  Linux* )
    lsys=true
    echo 'OS:Linux'
    ;;
esac

# STARTUP_PATH=/var/tmp/startup/
STARTUP_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! linux ]]; then
	echo '非Linux系统，暂不做配置处理'
	exit
fi

# isAliyunECS=true
if [[ ! isAliyunECS ]]; then
	echo '备份/etc/apt/sources.list文件为source.list.origin'
	cp /etc/apt/sources.list /etc/apt/sources.list.origin
	case "`head -n 1 /etc/issue`" in
		Ubuntu*18*)
			echo 'apt源替换为阿里云镜像'
			cp ${STARTUP_PATH}sources.list.aliyun.ubuntu.18.04 /etc/apt/sources.list
			;;
		Ubuntu*16*)
			echo 'apt源替换为阿里云镜像'
			cp ${STARTUP_PATH}sources.list.aliyun.ubuntu.16.04 /etc/apt/sources.list
			;;
		*)
			echo '不替换apt源文件'
			;;
	esac
fi

# apt
echo 'apt update && apt -y upgrade'
apt update && apt -y upgrade

# 安装zsh tmux git
echo '安装curl vim tree git htop zsh tmux'
apt install -qyy curl vim tree git htop zsh tmux
echo 'curl vim tree git htop zsh tmux安装完成'

command_exists docker || {
	echo '安装docker-ce'
	# 太慢了
	# curl -sSL https://get.docker.com | sudo sh

	# 改用阿里云的安源源
	echo '使用阿里云的安装源安装docker-ce'
	apt-get -y install apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
	apt-get -y update
	apt-get -y install docker-ce
}


command_exists docker-compose || {
	# 安装docker-compose
	## 这个也太慢了
	# curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
	## 改为直接复制
	cp ${STARTUP_PATH}docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
}



# 设置docker加速器
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://78gu089z.mirror.aliyuncs.com"]
}
EOF
systemctl daemon-reload
systemctl restart docker

# 安装on-my-zsh
echo '安装on-my-zsh'
# sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# 20200216注意: 修改默认切换shell到zsh
sh -c "${STARTUP_PATH}zsh_install.sh && exit"
echo 'on-my-zsh安装完成'


needMapGithubIP=false
if [[ needMapGithubIP ]]; then
	echo "处理git clone https://github.com/*/*速度缓慢的问题"
	export github=$(ping -c 1 github.global.ssl.fastly.net | grep PING | awk -F ' ' '{print $3}' | cut -d '('  -f 2 | cut -d ')' -f 1)
	if [[ ${#github} -eq 0 ]]; then
		echo 'github.global.ssl.fastly.net的IP地址为空，不解决github的加速问题'
	else 
		echo "github.global.ssl.fastly.net的IP地址为${github}" 
		echo "删除/etc/hosts文件中github.global.ssl.fastly.net域名网址映射"
		sed -i -- '/github.global.ssl.fastly.net/'d /etc/hosts > /dev/null 2>&1
		echo "在/etc/hosts文件中追加github.global.ssl.fastly.net域名网址映射"
		echo "${github} github.global.ssl.fastly.net" | tee -a /etc/hosts
		echo "git clone https://github.com/*/*速度缓慢的问题解决完成"
	fi
fi

## .gitconfig
git config --global push.default simple
# git config --global user.name "my-git-user-name"
# git config --global user.email "user-name@my.git"

# .tmux.conf
[[ ! -f ~/.tmux.conf ]] && tee ~/.tmux.conf <<-'EOF'
# bind a reload key
bind R source-file ~/.tmux.conf\; display-message "按Ctrl + b，再按R，重新加载~/.tmux.conf配置文件"\;

# 使用Ctrl + a作为tmux的默认快捷键
# 不习惯，还是使用原来的Ctrl + b作为默认的快捷键，暂时屏蔽
# unbind C-b
# set -g prefix C-a

# # invoke reattach-to-user-namespace every time a new window/pane opens
# set-option -g default-command "reattach-to-user-namespace -l /usr/local/bin/zsh"


# Use vim keybindings in copy mode
# TODO: 就算这行注释掉，vi模式依然有效。怎么回事？
setw -g mode-keys vi

# 可以把hjkl设置为切换窗格的快捷键：
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# 再给调整窗格大小设置快捷键：
bind L resize-pane -L 10  # 向左扩展
bind H resize-pane -R 10  # 向右扩展
bind K resize-pane -U 5   # 向上扩展
bind J resize-pane -D 5   # 向下扩展

# 使用%增加垂直窗格，使用"增加水平窗口
bind '"' split-window -c '#{pane_current_path}'
bind '%' split-window -h -c '#{pane_current_path}'

# tpm: tmux plugins manager
## 1. 先克隆tmux-plugins/tpm项目
##		git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
## 2. 将tmux-plugins/tpm的相关配置内容写在~/.tmux.conf文件的最底部
## List of plugins
## set -g @plugin 'tmux-plugins/tpm'
## set -g @plugin 'tmux-plugins/tmux-sensible'
## 
## # Other examples:
## # set -g @plugin 'github_username/plugin_name'
## # set -g @plugin 'git@github.com/user/plugin'
## # set -g @plugin 'git@bitbucket.com/user/plugin'
## 
## # Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
## run -b '~/.tmux/plugins/tpm/tpm'
## 3. 记住三个快捷键 prefix + I 、prefix + U 和 prefix + alt + u
## prefix + I 从github或指定仓库下载插件、安装并重新装载tmux环境配置；
## prefix + U 更新tmux插件
## prefix + alt + u 从~/.tmux/plugins目录移除和更新~/.tmux.conf插件列表对应的插件项目

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
run -b '~/.tmux/plugins/tpm/tpm'
EOF

# [[ -f ${STARTUP_PATH}global.env ]] && source ${STARTUP_PATH}global.env
# export LINUX_USERNAME=my-new-linux-username
# export LINUX_PASSWORD=my-new-linux-password

echo "LINUX_USERNAME=${LINUX_USERNAME}"

if [[ `id -u ${LINUX_USERNAME} >/dev/null 2>&1` ]]; then
	echo "已经有${LINUX_USERNAME}用户"
else
	# 没有${LINUX_USERNAME}用户
	echo "没有${LINUX_USERNAME}用户，正在创建${LINUX_USERNAME}用户"
	useradd -g 27 ${LINUX_USERNAME} -m
	# 因为ubuntu不支持`echo 'password' | passwd --stdin user1，改用chpasswd
	# 注意，为避免不必要的麻烦，不要用特殊字符
	echo "${LINUX_USERNAME}:${LINUX_PASSWORD}" | chpasswd
	echo "${LINUX_USERNAME}用户创建完成"
fi

[[ `id -u ${LINUX_USERNAME} >/dev/null 2>&1` ]] && [[ ! -f /home/${LINUX_USERNAME}/.tmux.conf ]] && cp ~/.tmux.conf /home/${LINUX_USERNAME}/.tmux.conf


# # 设置docker免sudo运行
# 方法1
# sudo gpasswd -a ${USER} docker &&  sudo usermod -aG docker ${USER}
# newgrp docker <<EONG
#   echo "hello from within newgrp"
#   id
#   cd ~
# EONG
## 方法2
groupadd docker
gpasswd -a ${LINUX_USERNAME} docker


# 切换用户后执行脚本
## 方法1
# su - ${LINUX_USERNAME} <<EOF
# 	pwd;
# 	exit;
# EOF
## 方法2
# su - ${LINUX_USERNAME} -c "pwd;"
## 方法3
# su - ${LINUX_USERNAME} -s /bin/bash shell.sh

# 为${LINUX_USERNAME}安装oh-my-zsh
su - ${LINUX_USERNAME} -s /bin/bash "${STARTUP_PATH}zsh_install.sh"
echo "为${LINUX_USERNAME}用户oh-my-zsh安装完成"

echo "全部配置完成"
