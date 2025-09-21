local skynet =require "skynet"
local service = require "service"
local runconfig =require "runconfig"
local socket =require "socket"

require "skynet.manager"


function shutdown_gate()
    for node,  _ in pairs()
    end
end


function stop()
    shutdown_gate()
    shutdown_agent()
    skynet.abort()           --结束skynet进程
end

function connect(fd, addr)
    socket.start(fd)
    socket.write(fd,"输入你的指令！\r\n")
    local cmd = socket.readline(fd,"\r\n")
    if cmd=="stop" then
        stop()
    end
end


function service.init()
    local listenfd = socket.listen("0.0.0.0",9500)
    socket.start(listenfd,connect)
end




service.start(...)