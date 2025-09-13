local skynet =require "skynet"
local service = require "service"
local pb =require "protobuf"

service.client={}
service.gate=nil

require "scene"

function service.resp.client(source,cmd,msg)
    service.gate=source
    if service.client[cmd] then
        local ret_msg,msgtype = service.client[cmd](msg,source)
        if ret_msg then
            skynet.send(source,"lua","send",service.id,msgtype,ret_msg)
        end
    else
        skynet.error("service.resp.client failed！",cmd)
    end
end


function service.init()
    pb.register_file("./proto/Cs_EnterRoom.pb")
    pb.register_file("./proto/player.pb")
    pb.register_file("./proto/food.pb")
end


function service.resp.kick(source)
    service.client.leave()
end

function service.resp.exit(source)
    skynet.exit()
end


function service.resp.send(source,msgtype,msg)
    skynet.send(service.gate,"lua","send",service.id,msgtype,msg)
end

service.start(...)