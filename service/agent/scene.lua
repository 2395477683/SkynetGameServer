local skynet =require "skynet"
local service =require "service"
local runconfig =require "runconfig"
local pb =require "protobuf"
local proto = require "proto"
local mynode = skynet.getenv("node")

service.sname = nil
service.snode = nil

local function random_scene()
    local nodes={}
    for i , v in pairs(runconfig.scene) do
        table.insert(nodes,i)
        if runconfig.scene[mynode] then
            table.insert(nodes,mynode)
        end
    end
    
    local idx =math.random(1,#nodes)
    local scenenode = nodes[idx]

    local scenelist=runconfig.scene[scenenode]
    local idx =math.random(1,#scenelist)
    local sceneid = scenelist[idx]
    return scenenode,sceneid
end

function service.client.enter()
    if service.sname then 
        return 
    end

    local snode,sid =random_scene()
    local sname="scene"..sid
    local isok=service.call(snode,sname,"enter",service.id,mynode,skynet.self())
    if not isok then 
        return 
    end
    service.sname = sname
    service.snode = snode
    return nil
end

function service.client.leave()
    if not service.sname then 
        return 
    end
    service.call(service.snode,service.sname,"leave",service.id)
    service.sname=nil
    service.snode=nil
end


function service.client.shift(msg)
    if not service.sname then 
        return 
    end
    local msg = proto.client_decode("shift",msg)
    local x = msg.direction_x or 0
    local y = msg.direction_y or 0
    service.call(service.snode,service.sname,"shift",service.id,x,y)
end

function service.client.fenlie()
    if not service.sname then 
        return 
    end
    service.call(service.snode,service.sname,"fenlie",service.id)
end

