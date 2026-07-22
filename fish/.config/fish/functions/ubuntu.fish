function ubuntu
    set current_network_name (networksetup -getairportnetwork en0 | awk -F' ' '{print $4}' | tr -d '\n') # 当前所在网络名称
    set local_network_name "home" # 局域网网络名称
    if test "$current_network_name" = "$local_network_name"
        ssh localubuntu
    else
        ssh remoteubuntu
    end
end

