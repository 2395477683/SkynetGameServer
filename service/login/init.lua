local skynet =require "skynet"
local service =require "service"
local redisHc = require "redisHc"
local pb = require "protobuf"
local proto = require "proto"

service.client={}

--用户登录
function service.client.login(fd,msg,source)
    local msg =proto.client_decode("login",msg)

    local playerid = msg.playerid
    local pw = msg.password
    local gate = source
    node = skynet.getenv("node")
    local date_msg = redisHc.get_player("string","",playerid)
    date_msg = proto.server_decode(service.msgtype.mysql.user,date_msg)
    local yanzhenmima = date_msg.password

    if pw ~= yanzhenmima then 
        if yanzhenmima == nil then
            return {cmd="login",result=2,info="账号未注册！"}
        else
            return{cmd="login",result=1,info="密码错误"}
        end
    end

    local isok,agent = skynet.call("agentmgr","lua","reqlogin",playerid,node,gate)
    if not isok then 
        return{cmd="login",result=1,info="mgr验证失败"}
    end

    local isok = skynet.call(gate,"lua","sure_agent",fd,playerid,agent)
    if not isok then 
        return {cmd="login",result=1,info="gate注册失败"}
    end

    skynet.error("用户 : "..playerid.." ，login succ")         
    
    local msgs = {player_status = "online"}
    local issucc,err= redisHc.update_player(playerid,msgs)

    local request_list=redisHc.get("list",":friend_request_list",playerid)
    if request_list ~= nil then
        for i , v in pairs(request_list) do 
            local request_msg = proto.server_decode(service.msgtype.mysql.request,v)

            local proto_msg={cmd="添加好友请求",result=1,info="玩家"..request_msg.from_user_id.."想要添加你为好友\r\n同意输入:YES,"..request_msg.from_user_id.."拒绝输入:NO,"..request_msg.from_user_id}
            proto_msg= proto.server_encode(service.msgtype.system,proto_msg)
            skynet.send(source,"lua","send",playerid,service.msgtype.system,proto_msg)

            local del_result = redisHc.del_list("friend_request_list:",playerid)
        end
    end

    return {cmd="login",result=0,info="登录成功！"}
end

--用户注册
function service.client.register(fd,msg,source)
    local msg =proto.client_decode("register",msg)

    if msg.playerid=="" or msg.password=="" or msg.username=="" then
        return {cmd="register",result=0,info="注册失败！请输入完整的信息！"}
    end
    local playerid = msg.playerid
    local password = msg.password
    local playername = msg.username
    local yanzhenid = redisHc.get_player("string","",playerid)
    if yanzhenid ~= nil then 
        return {cmd="register",result=0,info="账号已存在！"}
    end

    local sql = string.format("INSERT INTO user (playerid,password,username) VALUES (%s,%s,'%s')",playerid,password,playername)
    local user_data={
        playerid= playerid,
        password=password,
        username=playername,
        player_status="offline"
    }
    local user_msg=proto.server_encode(service.msgtype.mysql.user,user_data)
    redisHc.set("string","",playerid,user_msg, 3600)
    local ok = db:query(sql)
    if not ok then 
        return {cmd="register",result=0,info="注册失败！"}
    end

    return {cmd="register",result=1,info="注册成功！"}
end

--命令分发
function service.resp.client(source, fd, cmd, msg)
    if service.client[cmd] then
        local ret_msg=service.client[cmd](fd,msg,source)
        local protobuf_ret = proto.server_encode(service.msgtype.system,ret_msg)
        skynet.send(source,"lua","send_by_fd",fd,service.msgtype.system,protobuf_ret)
    else
        local ret_msg={cmd="error",result=0,info="错误的指令！"}
        local protobuf_ret = proto.server_encode(service.msgtype.system,ret_msg)
        skynet.send(source,"lua","send_by_fd",fd,service.msgtype.system,protobuf_ret)
        skynet.error("loginService.resp.client failed！",cmd)
    end
end

function service.init()
    redisHc.Hcinit()
    pb.register_file("./proto/Cs_Login.pb")
    pb.register_file("./proto/Sc_Login.pb")
    pb.register_file("./proto/player.pb")
end

service.start(...)