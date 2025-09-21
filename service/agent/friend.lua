local skynet =require "skynet"
local service =require "service"
local runconfig =require "runconfig"
local pb =require "protobuf"
local proto = require "proto"
local redisHc= require "redisHc"
local mynode = skynet.getenv("node")

--查看好友
function service.client.friend()
    local proto_msg={}
    local friendlist={}
    local friends = {} 

    --获取好友id和数据
    local friend_id_list = redisHc.get_player("list",":friend_id_list",service.id)
    for i , v in pairs(friend_id_list) do 
        local friend_id = proto.server_decode(service.msgtype.mysql.friend,v)
        local friend_data = redisHc.get_player("string","",friend_id.friend_id)
        friend_data = proto.server_decode(service.msgtype.mysql.user,friend_data)
        table.insert(friends,friend_data)      
    end

    for i , v in pairs(friends) do 
        local msg ={
            player_id = v.playerid,
            player_name = v.username,
            player_status = v.player_status
        }
        table.insert(friendlist,msg)
    end
    proto_msg.friendlist=friendlist
    proto_msg = proto.server_encode(service.msgtype.friend,proto_msg)
    return proto_msg,service.msgtype.friend
end

--发送请求
function service.client.send_request(msg,source)
    msg = proto.client_decode("send_request",msg)

    local from_user_id = service.id
    local to_user_id =msg.playerid

    --检查是否已经是好友
    local is_friend_sql  = string.format("SELECT id FROM friendships WHERE user_id = %s AND friend_id = %s AND status = 'rejected'",from_user_id, to_user_id)
    local is_friend = db:query(is_friend_sql)
    if is_friend and #is_friend > 0 then
        local msg ={cmd="friend",result=1,info="already is friend!"}
        msg = proto.server_encode(service.msgtype.system,msg)
        return msg,service.msgtype.system
    end
    
    --检查是否已有待处理请求
    local existing_request_sql  = string.format("SELECT id FROM friend_requests WHERE from_user_id = %s AND to_user_id = %s AND status = 'pending'",from_user_id, to_user_id)
    local existing_request = db:query(existing_request_sql)
    if existing_request and #existing_request > 0 then
        local msg ={cmd="friend",result=1,info="Request already sent!"}
        msg = proto.server_encode(service.msgtype.system,msg)
        return msg,service.msgtype.system
    end
    
    --创建好友请求
    local sql = string.format("INSERT INTO friend_requests (from_user_id, to_user_id, message) VALUES (%s, %s, '%s')",from_user_id, to_user_id, message or "")
    local ok, err = db:query(sql)
    if not ok then
        skynet.error("Failed to send request: " .. err) 
        return 
    end
    
    --检查目标用户是否在线
    local proto_msg = redisHc.get_player("string","",to_user_id)
    proto_msg = proto.server_decode(service.msgtype.mysql.user,proto_msg)
    is_online = proto_msg.player_status
    
    if is_online == "online" then
        --用户在线，直接推送请求
        local proto_msg={cmd="添加好友请求",result=1,info="玩家"..from_user_id.."想要添加你为好友\r\n同意输入:YES,"..from_user_id.."拒绝输入:NO,"..from_user_id}
        proto_msg= proto.server_encode(service.msgtype.system,proto_msg)
        skynet.send(service.gate,"lua","send",to_user_id,service.msgtype.system,proto_msg)
    else
        --用户离线，存储请求等待用户上线  
        --获取请求 
        local to_request_sql  = string.format("SELECT * from friend_requests where to_user_id = %s and from_user_id = %s",to_user_id,from_user_id)
        local request_sql = db:query(to_request_sql)
        --推送到redis
        if #request_sql ~= 0 then
            local result_msg = proto.server_encode(service.msgtype.mysql.request,request_sql[1])
            redisHc.set("list",":friend_request_list",to_user_id,result_msg)
        end
    end

    --结果响应
    local result_msg ={cmd="friend",result=1,info="添加请求已发送"}
    result_msg = proto.server_encode(service.msgtype.system,result_msg)
    return result_msg,service.msgtype.system
end

--同意添加好友
function service.client.YES(msg)
    msg = proto.client_decode("YES",msg)

    --检查是否存在好友请求
    local id_sql = string.format("SELECT id from friend_requests where to_user_id = %s and from_user_id = %s",service.id,msg.playerid)
    local isok,err = db:query(id_sql)
    if not isok then
        skynet.error("befriend failed :",err)
    end

    --获取玩家数据
    local friend_msg = redisHc.get_player("string","",msg.playerid)
    if not friend_msg then 
        skynet.error("get friend_date failed :",err)
    end
    friend_msg = proto.server_decode(service.msgtype.mysql.user,friend_msg)

    --更新好友表
    local update_sql = string.format("INSERT INTO friendships (user_id, friend_id,status) VALUES (%s, %s, '%s')",msg.playerid, service.id, "accepted")
    local ok, err = db:query(update_sql)
    if not ok then
        return false, "Failed to update friendships: " .. err
    end
    local res = db:query("SELECT * FROM friendships WHERE user_id = " .. msg.playerid)
    if #res ~= 0 then
       res = proto.server_encode(service.msgtype.mysql.friend,res[1])
    end
    redisHc.set("string",":friend_ships",msg.playerid, res, 3600) --1小时

    local res = db:query("SELECT friend_id FROM friendships WHERE user_id = " .. msg.playerid)
    local result_table = {}
    if #res ~= 0 then      
        for i , v in ipairs (res) do
            local proto_v = proto.server_encode(service.msgtype.mysql.friend,v)
            result_table[i]  =  proto_v
        end
    end
    redisHc.invalidate("list",":friend_id_list",msg.playerid)
    for i , v in ipairs(result_table) do
        redisHc.set("list",":friend_id_list",msg.playerid, v, 3600) --1小时
    end


    --更新好友表
    local update_sql = string.format("INSERT INTO friendships (user_id, friend_id,status) VALUES (%s, %s, '%s')",service.id, msg.playerid, "accepted")
    local ok, err = db:query(update_sql)
    if not ok then
        return false, "Failed to update friendships: " .. err
    end
    local res = db:query("SELECT * FROM friendships WHERE user_id = " .. service.id)
    if #res ~= 0 then
       res = proto.server_encode(service.msgtype.mysql.friend,res[1])
    end
    redisHc.set("string",":friend_ships",service.id, res, 3600) --1小时
    local res = db:query("SELECT friend_id FROM friendships WHERE user_id = " .. service.id)
    local result_table = {}
    if #res ~= 0 then      
        for i , v in ipairs (res) do
            local proto_v = proto.server_encode(service.msgtype.mysql.friend,v)
            result_table[i]  =  proto_v
        end
    end
    redisHc.invalidate("list",":friend_id_list",service.id)
    for i , v in ipairs(result_table) do
        redisHc.set("list",":friend_id_list",service.id, v, 3600) --1小时
    end

    --删除好友请求
    local sql = string.format("DELETE FROM friend_requests where to_user_id = %s and from_user_id = %s",service.id,msg.playerid)
    local ok, err = db:query(sql)
    if not ok then
        return false, "Failed to update friendships: " .. err
    end

    --结果响应
    local result_msg ={cmd="friend",result=1,info="你和玩家"..msg.playerid.."成为好友"}
    result_msg = proto.server_encode(service.msgtype.system,result_msg)
    return result_msg,service.msgtype.system
end


--拒绝添加好友
function service.client.NO(msg)
    msg = proto.client_decode("NO",msg)

    local sql = string.format("DELETE FROM friend_requests where to_user_id = %s and from_user_id = %s",service.id,msg.playerid)
    local ok, err = db:query(sql)
    if not ok then
        return false, "Failed to update friendships: " .. err
    end

    local result_msg={cmd="friend",result=1,info="玩家"..service.id.."拒绝成为你的好友"}
    result_msg= proto.server_encode(service.msgtype.system,result_msg)
    skynet.send(service.gate,"lua","send",msg.playerid,service.msgtype.system,result_msg)
end

--删除好友
function service.client.delfriend(msg)
    msg = proto.client_decode("delfriend",msg)

    --删除数据库数据
    local sql = string.format("DELETE FROM friendships where user_id = %s and friend_id = %s",service.id,msg.playerid)
    local ok, err = db:query(sql)
    if not ok then
        return false, "Failed to update friendships: " .. err
    end
    
    local sql = string.format("DELETE FROM friendships where friend_id = %s and user_id = %s",service.id,msg.playerid)
    local ok, err = db:query(sql)
    if not ok then
        return false, "Failed to update friendships: " .. err
    end

    --修改redis
    local res = db:query("SELECT friend_id FROM friendships WHERE user_id = " .. msg.playerid)
    local result_table = {}
    if #res ~= 0 then      
        for i , v in ipairs (res) do
            local proto_v = proto.server_encode(service.msgtype.mysql.friend,v)
            result_table[i]  =  proto_v
        end
    end
    redisHc.invalidate("list",":friend_id_list",msg.playerid)
    for i , v in ipairs(result_table) do
        redisHc.set("list",":friend_id_list",msg.playerid, v, 3600) --1小时
    end

    local res = db:query("SELECT friend_id FROM friendships WHERE user_id = " .. service.id)
    local result_table = {}
    if #res ~= 0 then      
        for i , v in ipairs (res) do
            local proto_v = proto.server_encode(service.msgtype.mysql.friend,v)
            result_table[i]  =  proto_v
        end
    end
    redisHc.invalidate("list",":friend_id_list",service.id)
    for i , v in ipairs(result_table) do
        redisHc.set("list",":friend_id_list",service.id, v, 3600) --1小时
    end

    --结果响应
    local result_msg ={cmd="friend",result=1,info="成功删除玩家"..msg.playerid}
    result_msg = proto.server_encode(service.msgtype.system,result_msg)
    return result_msg,service.msgtype.system
end