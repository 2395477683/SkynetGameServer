local skynet=require "skynet"
local service =require "service"


function service.resp.newservice(source ,name , ...)
    local srv =skynet.newservice(name,...)
    return srv
end

service.start(...)