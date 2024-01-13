function proxy_v2ray
    set -x http_proxy http://127.0.0.1:1087
    set -x https_proxy http://127.0.0.1:1087
    set -x ALL_PROXY socks5://127.0.0.1:1080
    git config --global http.proxy "127.0.0.1:1087" # git 代理
    git config --global https.proxy "127.0.0.1:1087" # git 代理
end

