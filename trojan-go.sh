#!/bin/bash

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
systemctl stop ufw
systemctl disable ufw

release="ubuntu"
systemPackage="apt-get"
systempwd="/lib/systemd/system/"
your_domain="sight.ourszone.top"
trojan_passwd="0Onl1ine"

applyfor_https(){
    apt update
    $systemPackage -y install nginx certbot wget unzip zip curl tar  >/dev/null 2>&1
    systemctl enable nginx.service
    
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr != $local_addr ] ; then
        green "=========================================="
        red "域名解析地址  $real_addr 与本地地址 $local_addr 不符"
        green "=========================================="
        exit 1
    fi
cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
}
EOF
    systemctl restart nginx.service
    #申请https证书
    certbot certonly --agree-tos --email moacs@msn.com --webroot -w /usr/share/nginx/html -d $your_domain
    if test -s /etc/letsencrypt/live/$your_domain/fullchain.pem; then
        green "=========================================="
        yellow "证书申请成功"
        green "=========================================="
    else
        green "=========================================="
        red "证书申请失败"
        green "=========================================="
        exit 1
    fi
}
install_trojan-go(){
    git config --global user.email "i@moacs.com"
    git config --global user.name "moacs"
    cd /etc
    git clone https://gitee.com/moacs/cross.git letsencrypt
    cd letsencrypt
    git checkout -b letsencrypt origin/letsencrypt
    cd /srv
    wget https://github.com//p4gefau1t/trojan-go/releases/download/v0.10.6/trojan-go-linux-amd64.zip
    unzip -d trojan-go trojan-go-linux-amd64.zip
    rm -rf /srv/trojan-go/config.json
	cat > /srv/trojan-go/config.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/etc/letsencrypt/live/$your_domain/fullchain.pem",
        "key": "/etc/letsencrypt/live/$your_domain/privkey.pem",
        "sni": "$your_domain"
    },
    "websocket": {
        "enabled": true,
        "path": "/socket",
        "hostname": "$your_domain"
    },
    "mux": {
        "enabled": true
    }
}
EOF
    
cat > ${systempwd}trojan-go.service <<-EOF
[Unit]
Description=trojan-go
After=network.target

[Service]
Type=simple
PIDFile=/srv/trojan-go/trojan-go/trojan-go.pid
ExecStart=/srv/trojan-go/trojan-go -config "/srv/trojan-go/config.json"
ExecReload=
ExecStop=/srv/trojan-go/trojan-go
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    chmod +x ${systempwd}trojan-go.service
    systemctl start trojan-go.service
    systemctl enable trojan-go.service
    green "trojan-go已安装完成"
}

remove_trojan-go(){
    red "================================"
    red "即将卸载trojan-go"
    red "同时卸载安装的nginx"
    red "================================"
    systemctl stop trojan-go
    systemctl disable trojan-go
    rm -f ${systempwd}trojan-go.service
    apt autoremove -y nginx
    rm -rf /srv/trojan-go*
    rm -rf /usr/share/nginx/html/*
    green "=============="
    green "trojan-go删除完毕"
    green "=============="
}

bbr_boost_sh(){
    bash <(curl -L -s -k "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh")
}
start_menu(){
    clear
    green " ===================================="
    green " trojan-go 一键安装自动脚本      "
    green " ===================================="
    echo
    red " ===================================="
    yellow " 1. 一键安装 trojan-go"
    red " ===================================="
    yellow " 2. 安装 4 IN 1 BBRPLUS加速脚本"
    red " ===================================="
    yellow " 3. 一键卸载 trojan-go"
    red " ===================================="
    yellow " 4. 申请https证书"
    red " ===================================="
    yellow " 5. 安装 trojan-go"
    red " ===================================="
    yellow " 0. 退出脚本"
    red " ===================================="
    echo
    read -p "请输入数字:" num
    case "$num" in
        1)
            yellow "==========请输入域名============="
            read your_domain
            yellow "==========请输入密码============="
            read trojan_passwd
            applyfor_https
            
            install_trojan-go
        ;;
        2)
            bbr_boost_sh
        ;;
        3)
            remove_trojan-go
        ;;
        4)
            yellow "==========请输入域名============="
            read your_domain
            applyfor_https
        ;;
        5)
            yellow "==========请输入域名============="
            read your_domain
            yellow "==========请输入密码============="
            read trojan_passwd
            install_trojan-go
        ;;
        0)
            exit 1
        ;;
        *)
            clear
            red "请输入正确数字"
            sleep 1s
            start_menu
        ;;
    esac
}

start_menu


# scp -r root@sight.moacs.com:/etc/letsencrypt/ ./ssl
# https://jeanniestudio.top/2020/07/17/%E6%89%8B%E5%8A%A8%E6%90%AD%E5%BB%BATrojan-go+Nginx+Tls%20-%20%E5%89%AF%E6%9C%AC/