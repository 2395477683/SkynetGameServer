local skynet=require "skynet"
local cluster =require "skynet.cluster"
local runconfig = require "runconfig"
local mysql= require "skynet.db.mysql"

local M ={
    --服务的类型和id
    name = "",
    id = 0,
    --服务的回调函数
    exit =nil,
    init =nil,
    --服务的分发方法
    resp={},
    --消息的类型
    msgtype ={
        player = 1,
        food = 2,
        system =3,
        leader =4
    }
}




function traceback(err)
    skynet.error(tostring(err))
    skynet.error(debug.traceback())
end


local dispatch = function(session,address,cmd,...)
    local fun=M.resp[cmd]
    if not fun then 
        skynet.error("没有这个方法！"..cmd)
        return 
    end

    local ret =table.pack(xpcall(fun,traceback,address,...))
    local isok=ret[1]

    if not ret[1] then 
        return 
    end

    skynet.retpack(table.unpack(ret,2))
end

--初始化
function init()
    skynet.dispatch("lua",dispatch)
    db = mysql.connect({
        host="10.14.184.31",
        port="3306",
        database="gamedate",
        user="root",
        password="macan344",
        max_packet_size=1024*1024,
        on_connect=nil
    })

    if M.init then 
        M.init()
    end
end

--启动服务
function M.start(name,id,...)
    M.name =name 
    M.id = id
    skynet.start(init)
end


--辅助函数
function M.call(node,srv,...)
    local mynode=skynet.getenv("node")
    if node == mynode then
        return skynet.call(srv,"lua",...)
    else    
        return cluster.call(node,srv,...)
    end
end

function M.send(node,srv,...)
    local mynode=skynet.getenv("node")
    if node == mynode then 
        return skynet.send(srv,"lua",...)
    else
        return cluster.send(node,srv,...)
    end
end 


return M