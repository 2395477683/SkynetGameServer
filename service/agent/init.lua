local skynet =require "skynet"
local service = require "service"


service.client={}
service.gate=nil

require "scene"

function service.resp.client(source,cmd,msg)
    service.gate=source
    if service.client[cmd] then
        local ret_msg = service.client[cmd](msg,source)
        if ret_msg then
            print("2 "..type(service.id))
            skynet.send(source,"lua","send",service.id,ret_msg)
        end
    else
        skynet.error("service.resp.client failed！",cmd)
    end
end


function service.init()
    local data=db:query("select coin from userdata where playerid = "..service.id)
    local coins,hps
    for i , v in pairs(data) do 
        for j,k in pairs(v) do 
            coins=k
        end
    end
    data=db:query("select hp from userdata where playerid = "..service.id)
    for i , v in pairs(data) do 
        for j,k in pairs(v) do 
            hps=k
        end
    end
    service.data={
        coin=coins,
        hp=hps,
    }
end

function service.client.work(msg)
    service.data.coin=service.data.coin+1
    return {"work",service.data.coin}
end


function service.resp.kick(source)
    service.leave_scene()
    db:query("update userdata set coin ="..service.data.coin.." where playerid = "..service.id )
end

function service.resp.exit(source)
    skynet.exit()
end


function service.resp.send(source,msg)
    skynet.send(service.gate,"lua","send",service.id,msg)
end

service.start(...)