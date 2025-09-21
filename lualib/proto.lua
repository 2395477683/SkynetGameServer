local pb = require "protobuf"
local skynet = require "skynet"
local service =require "service"

local M ={}


--对客户端请求进行序列化
function M.client_encode(cmds,msg)
    local buff =""
    if cmds == "login" or cmds == "register" then
        local msg ={
            playerid = msg[2] or "",
            password = msg[3] or "",
            username = msg[4] or ""
        }
        buff = pb.encode("Cs_Login.Cs_Login",msg)
    elseif  cmds ==  "shift"  then
        local msg ={
            direction_x = msg[2],
            direction_y = msg[3] 
        }
        buff = pb.encode("Cs_EnterRoom.Cs_EnterRoom",msg)
    elseif  cmds ==  "friend"  then
        local msg ={
            username = msg[2] or ""
        }
        buff = pb.encode("Cs_Login.Cs_Login",msg) 
    elseif cmds == "YES" or cmds == "NO" or cmds == "send_request" or cmds == "delfriend" then
        local msg ={
            playerid = msg[2] or ""
        }
        buff = pb.encode("Cs_Login.Cs_Login",msg)
    end 
    return buff
end

--对服务器端回应进行序列化
function M.server_encode(msgtype,msg)
    local buff
    
    if msgtype==service.msgtype.player.players then
        buff = pb.encode("player.player",msg)
    elseif msgtype==service.msgtype.player.balls then
        buff = pb.encode("player.playerlist",msg)
    elseif msgtype==service.msgtype.food.foodlist then
        buff = pb.encode("food.foodlist",msg)
    elseif msgtype==service.msgtype.food.foods then
        buff = pb.encode("Sc_Login.Sc_food",msg)
    elseif msgtype==service.msgtype.system then
        buff = pb.encode("Sc_Login.Sc_Login",msg)
    elseif msgtype==service.msgtype.leader then
        buff = pb.encode("leader.leaderboard",msg)
    elseif msgtype==service.msgtype.eat then
        buff = pb.encode("Sc_Login.Sc_eat",msg)
    elseif msgtype==service.msgtype.friend then
        buff = pb.encode("friend.friendlist",msg)
    elseif msgtype==service.msgtype.mysql.user then
        buff = pb.encode("Mysql.Mysql_user",msg)
    elseif msgtype==service.msgtype.mysql.friend then
        buff = pb.encode("Mysql.Mysql_friend",msg)
    elseif msgtype==service.msgtype.mysql.request then
        buff = pb.encode("Mysql.Mysql_friend_request",msg)
    end

    return buff
end


--对服务器端回应进行反序列化
function M.server_decode(msgtype,msg)
    local buff

    if msgtype==service.msgtype.player.players then
        buff = pb.decode("player.player",msg)
    elseif msgtype==service.msgtype.player.balls then
        buff = pb.decode("player.playerlist",msg)
    elseif msgtype==service.msgtype.food.foodlist then
        buff = pb.decode("food.foodlist",msg)
    elseif msgtype==service.msgtype.food.foods then
        buff = pb.decode("Sc_Login.Sc_food",msg)
    elseif msgtype==service.msgtype.system then
        buff = pb.decode("Sc_Login.Sc_Login",msg)
    elseif msgtype==service.msgtype.leader then
        buff = pb.decode("leader.leaderboard",msg)
    elseif msgtype==service.msgtype.eat then
        buff = pb.decode("Sc_Login.Sc_eat",msg)
    elseif msgtype==service.msgtype.friend then
        buff = pb.decode("friend.friendlist",msg)
    elseif msgtype==service.msgtype.mysql.user then
        buff = pb.decode("Mysql.Mysql_user",msg)
    elseif msgtype==service.msgtype.mysql.friend then
        buff = pb.decode("Mysql.Mysql_friend",msg)
    elseif msgtype==service.msgtype.mysql.request then
        buff = pb.decode("Mysql.Mysql_friend_request",msg)
    end

    return buff
end

--对客户端请求进行反序列化
function M.client_decode(cmds,msg)
    local buff 
    if cmds == "login" or cmds == "register" or cmds == "friend" or cmds == "YES" or cmds == "NO" or cmds == "send_request" or cmds == "delfriend" then
        buff = pb.decode("Cs_Login.Cs_Login",msg)
    elseif  cmds == "shift"  then
        buff = pb.decode("Cs_EnterRoom.Cs_EnterRoom",msg)
    end 
    return buff
end

return M