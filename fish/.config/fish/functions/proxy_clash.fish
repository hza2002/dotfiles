function proxy_clash
    set -x https_proxy http://127.0.0.1:7890
    set -x http_proxy http://127.0.0.1:7890
    set -x all_proxy socks5://127.0.0.1:7890
    git config --global http.proxy "127.0.0.1:7890" # git 代理
    git config --global https.proxy "127.0.0.1:7890" # git 代理
end
