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

release="ubuntu"
systemPackage="apt-get"
systempwd="/lib/systemd/system/"
your_domain=""
trojan_passwd=""

applyfor_https(){
    systemctl stop ufw
    systemctl disable ufw
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
install_trojan(){
    cd /srv
    wget https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
    tar xf trojan-1.*
    rm -rf /srv/trojan/config.json
	cat > /srv/trojan/config.json <<-EOF
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
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	    "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF
    
cat > ${systempwd}trojan.service <<-EOF
[Unit]
Description=trojan
After=network.target

[Service]
Type=simple
PIDFile=/srv/trojan/trojan/trojan.pid
ExecStart=/srv/trojan/trojan -c "/srv/trojan/config.json"
ExecReload=
ExecStop=/srv/trojan/trojan
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    chmod +x ${systempwd}trojan.service
    systemctl start trojan.service
    systemctl enable trojan.service
    green "Trojan已安装完成"
}

remove_trojan(){
    red "================================"
    red "即将卸载trojan"
    red "同时卸载安装的nginx"
    red "================================"
    systemctl stop trojan
    systemctl disable trojan
    rm -f ${systempwd}trojan.service
    apt autoremove -y nginx
    rm -rf /srv/trojan*
    rm -rf /usr/share/nginx/html/*
    green "=============="
    green "trojan删除完毕"
    green "=============="
}

bbr_boost_sh(){
    bash <(curl -L -s -k "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh")
}
start_menu(){
    clear
    green " ===================================="
    green " Trojan 一键安装自动脚本      "
    green " ===================================="
    echo
    red " ===================================="
    yellow " 1. 一键安装 Trojan"
    red " ===================================="
    yellow " 2. 安装 4 IN 1 BBRPLUS加速脚本"
    red " ===================================="
    yellow " 3. 一键卸载 Trojan"
    red " ===================================="
    yellow " 4. 申请https证书"
    red " ===================================="
    yellow " 5. 安装 Trojan"
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
            
            install_trojan
        ;;
        2)
            bbr_boost_sh
        ;;
        3)
            remove_trojan
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
            install_trojan
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
