local skynet =require "skynet"
local service=require "service"
local proto = require "proto"
local pb = require "protobuf"

STATUS={
    LOGIN=2,
    GAME=3,
    LOGOUT=4
}

local players={}


function mgrplayer()
    m={
        playerid = nil,
        node=nil,
        gate=nil,
        status=nil,
        agent=nil,
    }

    return m
end

function service.resp.reqlogin(source,playerid,node,gate)
    local mplayer = players[playerid]
    if mplayer and mplayer.status==STATUS.LOGIN then 
        skynet.error("Otheruser Loging!")
        return false
    elseif mplayer and mplayer.status==STATUS.LOGOUT then 
        skynet.error("Otheruser Loginouting!")
        return false
    elseif mplayer then 
        local pnode = mplayer.node
        local pagent=mplayer.agent
        local pgate = mplayer.gate
        mplayer.status = STATUS.LOGOUT
        skynet.error("kick")
        service.call(pnode,pagent,"kick")
        service.send(pnode,pagent,"exit")
        local msg = {cmd="kick",result=1,info="你被其他人顶替下线"}
        msg = proto.server_encode(service.msgtype.system,msg)
        service.send(pnode,pgate,"send",playerid,service.msgtype.system,msg)
        service.call(pnode,pgate,"kick",playerid)
    end

    local player =mgrplayer()
    player.playerid=playerid
    player.agent=nil
    player.gate=gate
    player.node=node
    player.status=STATUS.LOGIN

    players[playerid]=player

    local agent=service.call(node,"nodemgr","newservice","agent","agent",playerid)
    player.agent=agent
    player.status=STATUS.GAME
    return true,agent
end

function service.resp.reqkick(source,playerid,reason)
    local player=players[playerid]
    if not player then 
        return false
    end

    if player.status ~= STATUS.GAME then
        return false
    end

    player.status=STATUS.LOGOUT
    local pnode =player.node
    local pagent=player.agent
    local pgate=player.gate

    service.call(pnode,pagent,"kick")
    service.send(pnode,pagent,msgtype,"exit")
    service.call(pnode,pgate,"kick",playerid)
    player[playerid]=nil
    return true
end

function service.init()
    pb.register_file("./proto/Sc_Login.pb")
end

service.start(...)