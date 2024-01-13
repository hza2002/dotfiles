function ubuntu
    set current_network_name (networksetup -getairportnetwork en0 | awk -F' ' '{print $4}' | tr -d '\n') # 当前所在网络名称
    set local_network_name "swu" # 局域网网络名称
    set success_command "ssh localubuntu" # 要执行的命令，如果Ping成功
    set failure_command "ssh remoteubuntu" # 要执行的命令，如果Ping失败
    # 使用ping命令来检测是否可以Ping通地址
    if test "$current_network_name" = "$local_network_name"
        # 如果Ping成功，则执行成功命令
        eval $success_command
    else
        # 如果Ping失败，则执行失败命令
        eval $failure_command
    end
end

