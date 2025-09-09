local skynet =require "skynet"
local service =require "service"


service.client={}

--用户登录
function service.client.login(fd,msg,source)
    local playerid = msg[2]
    print(type(playerid))
    local pw = tostring(msg[3])
    local gate = source
    node = skynet.getenv("node")
    local yanzhenmimas = db:query("select password from user where playerid = "..playerid)
    local yanzhenmima
    for i, v in pairs(yanzhenmimas) do
        for j,k in pairs(v) do 
            yanzhenmima=tostring(k)
        end
    end
    skynet.error(yanzhenmima,pw)
    if pw ~= yanzhenmima then 
        return{"login",1,"密码错误"}
    end
    skynet.error("agent")
    local isok,agent = skynet.call("agentmgr","lua","reqlogin",playerid,node,gate)
    if not isok then 
        return{"login",1,"mgr验证失败"}
    end

    local isok = skynet.call(gate,"lua","sure_agent",fd,playerid,agent)
    if not isok then 
        return {"login",1,"gate注册失败"}
    end

    skynet.error("用户 : "..playerid.." ，login succ")

    return {"login",0,"登录成功！"}
end

--用户注册
function service.client.register(fd,msg,source)
    if msg[2]==nil or msg[3]==nil or msg[4]==nil then
        return {"register",0,"注册失败！请输入完整的信息！"}
    end
    local playerid = tostring(msg[2])
    local password = tostring(msg[3])
    local playername = tostring(msg[4])
    local yanzhenid = db:query("select playerid from user where playerid ="..playerid)
    if #yanzhenid ~= 0 then 
        print("测试！ ",yanzhenid[1].playerid)
        return {"register",0,"账号已存在！"}
    end

    local sql = string.format("INSERT INTO user (playerid, password,username) VALUES (%s,%s,%s)",playerid,password,playername)
    print("测试！",sql)
    local ok = db:query(sql)
    if not ok then 
        return {"register",0,"注册失败！"}
    end

    return {"register",1,"注册成功！"}
end

function service.resp.client(source, fd, cmd , msg)
    if service.client[cmd] then
        local ret_msg=service.client[cmd](fd,msg,source)
        skynet.send(source,"lua","send_by_fd",fd,ret_msg)
    else
        skynet.error("loginService.resp.client failed！",cmd)
    end
end


service.start(...)