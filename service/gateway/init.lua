local skynet =require "skynet"
local service = require "service"
local socket =require "skynet.socket"
local runconfig = require "runconfig"
local pb =require "protobuf"
local proto = require "proto"

conns={}
players={}

--连接类
function conn()
    local m={
        fd=nil,
        playerid=nil,
    }
    return m
end

--玩家类
function player()
    local m={
        playerid=nil,
        agent=nil,
        conn=nil
    }
    return m
end

--对客户端指令解码
local str_unpack = function (msgstr)
    local msg={}

    while true do
        local arg,reset = string.match(msgstr,"(.-),(.*)")
        if arg then
            msgstr = reset
            table.insert(msg,arg)
        else
            table.insert(msg,msgstr)
            break
        end
    end

    return msg[1],msg
end

--构建发送给客户端的信息
local str_pack = function (msg)
    local str = ""
    str= msg.cmd..","..msg.result..","..msg.info.."\r\n"
    return str
end

--检查是否登录
function process_msg(fd,msgstr)
    local cmds,msg=str_unpack(msgstr)
    skynet.error("recv "..fd.. " [ "..cmds.." ] { "..table.concat(msg,",").." } ")

    local conn =conns[fd]
    local playerid = conn.playerid

    if not playerid then
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1,#nodecfg.login)
        local login ="login"..loginid
        local proto_msg=proto.client_encode(cmds,msg)                     --序列化

        skynet.send(login,"lua","client",fd,cmds,proto_msg)
    else
        local proto_msg=proto.client_encode(cmds,msg)                     --序列化
        local gplayer = players[playerid]
        local agent = gplayer.agent
        skynet.send(agent,"lua","client",cmds,proto_msg)
    end
end 


function process_buf(fd,readbuf)

    while true do
        local msgstr,reset=string.match(readbuf,"(.-)\r\n(.*)")
        if msgstr then
            readbuf = reset
            process_msg(fd , msgstr)
        else
            return readbuf
        end
    end
end


function disconnect(fd)
    local c = conns[fd]
    if not c then
        return 
    end

    local playerid =c.playerid
    if not playerid then
        return 
    else
        players[playerid]=nil
        local reason ="断线"
        skynet.call("agentmgr","lua","reqkick",playerid,reason)
    end
end


local recv_loop=function (fd)
    socket.start(fd)
    skynet.error("Fd : "..fd.." 连接成功！")
    local startbuf = [[
    欢迎来到球吃球大作战！ 
    你可以使用以下命令：
    注册：register,你的账号,你的密码,玩家姓名
    登录：login,你的账号,你的密码
    加入一局游戏：enter
    移动：shift,x方向速度(数字),y方向速度(数字)
    分裂：fenlie
    离开游戏:leave
]]
    socket.write(fd,startbuf)
    local readbuf=""
    while true do
        local recvstr=socket.read(fd)
        if recvstr then
            readbuf=readbuf..recvstr
            readbuf=process_buf(fd,readbuf)
        else
            skynet.error("skynet close:"..fd)
            disconnect(fd)
            socket.close(fd)
            return
        end
    end
end


function connect(fd,address)
    skynet.error(address.." 请求连接。 Fd ： "..fd)
    local c =conn()
    conns[fd]=c
    c.fd=fd
    skynet.fork(recv_loop,fd)                   --开启协程调用 recv_loop
end



function service.resp.send_by_fd(source,fd,msgtype,msg)
    if not conns[fd] then
        skynet.error("客户端未连接！")
        return
    end
    local buff =proto.server_decode(msgtype,msg)                --反序列化
    --日志
    skynet.error("msgtype: "..msgtype..",send : "..fd.." [ "..buff.cmd.." ]{ "..buff.cmd..","..buff.result..","..buff.info.." }")

    buff = str_pack(buff)

    socket.write(fd,buff)
end

function service.resp.send(source,playerid,msgtype,msg)
    local gplayer = players[playerid]
    if gplayer== nil then
        return
    end
    local c = gplayer.conn
    if c == nil then 
        return 
    end
    service.resp.send_by_fd(nil,c.fd,msgtype,msg)
end


function service.resp.sure_agent(source,fd,playerid,agent)
    local conn =conns[fd]
    skynet.error("conn",conn)
    if not conn then
        return 
    end

    conn.playerid = playerid

    local gplayer = player()
    gplayer.playerid = playerid
    gplayer.agent=agent
    gplayer.conn=conn
    players[playerid]=gplayer

    skynet.error(playerid,conn,agent,players[playerid])

    return true

end


function service.resp.kick(source,playerid)
    local gplayer=players[playerid]
    if not gplayer then 
        return 
    end

    local c =gplayer.conn
    players[playerid]=nil
    if not c then
        return 
    end
    conns[c.fd]=nil
    disconnect(c.fd)
    socket.close(c.fd)
end



function service.init()                                                 --gateWay服务初始化
    skynet.error("[start] "..service.name.." "..service.id)
    local node = skynet.getenv("node")
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[tonumber(service.id)].port

    pb.register_file("./proto/Cs_Login.pb")
    pb.register_file("./proto/Sc_Login.pb")
    pb.register_file("./proto/Cs_EnterRoom.pb")
    pb.register_file("./proto/player.pb")

    local listenfd = socket.listen("0.0.0.0",port)
    skynet.error("Listen Socket : 0.0.0.0 Port: "..port)
    socket.start(listenfd,connect)

end


service.start(...)

