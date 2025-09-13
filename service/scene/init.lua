local service = require "service"
local skynet = require "skynet"
local redisHc = require "redisHc"
local leaderboard = require "leaderboard"
local pb = require "protobuf"
local proto = require "proto"

local balls = {}            --存储玩家
local foods={}
local food_maxid=0
local food_count=0

--球实例
function ball () 
    local m={
        playerid =nil,
        node=nil,
        agent=nil,
        x = math.random(0,100),
        y = math.random(0,100),
        size=2,
        speedx = 0,
        speedy = 0,
    }

    local ms={}
    table.insert(ms,m)
    --测试print("ms.m.playerid: "..ms[1].size)
    return ms
end

--所有玩家
local function balllist_msg()
    local msg={cmd="balllist"}
    local ball={}
    for i , v in pairs(balls) do 
        for j, k in pairs(v) do 
        local player_msg={}
        player_msg.playerid=k.playerid
        player_msg.player_x=k.x
        player_msg.player_y=k.y
        player_msg.player_size=k.size
        table.insert(ball,player_msg)
        end
    end
    msg.ball=ball
    msg = proto.server_encode(service.msgtype.player.balls,msg)
    return msg
end

--食物实例
local function food()
    local m={
        id=nil,
        x=math.random(0,100),
        y=math.random(0,100)
    }
    return m
end

--全部食物
local function foodlist_msg()
    local msg = {cmd="foodlist"}
    local foodlist ={}
    for i , v in pairs(foods) do
        local food_msg ={}
        food_msg.foodid=v.id
        food_msg.food_x=v.x
        food_msg.food_y=v.y
        table.insert(foodlist,food_msg)
    end
    msg.foodlist=foodlist
    msg = proto.server_encode(service.msgtype.food.foodlist,msg)
    return msg
end

--广播
function broadcast(msg,msgtype)
    for i , v in pairs(balls) do
        service.send(v[1].node,v[1].agent,"send",msgtype,msg)
    end
end

function service.resp.enter(source,playerid,node,agent)
    if balls[playerid] then 
        return 
    end
    local b =ball()
    b[1].playerid =playerid
    b[1].node = node 
    b[1].agent =agent
    --广播玩家信息
    local entermsg = {cmd="enter",result=1,info="玩家"..playerid.."加入游戏！"}
    entermsg = proto.server_encode(service.msgtype.system,entermsg)
    broadcast(entermsg,service.msgtype.system)
    --更新排行榜记录
    leaderboard.update_score(service.name,playerid,b[1].size)
    --记录
    balls[playerid]=b
    --[[测试
    print("测试 :"..playerid)
    print(balls[playerid])
    --]]
    --回应客户端
    local ret_msg={cmd="enter",result=0,info="进入游戏！"}
    ret_msg = proto.server_encode(service.msgtype.system,ret_msg)
    --发送游戏信息
    service.send(b[1].node,b[1].agent,"send",service.msgtype.system,ret_msg)
    service.send(b[1].node,b[1].agent,"send",service.msgtype.player.balls,balllist_msg())
    service.send(b[1].node,b[1].agent,"send",service.msgtype.food.foodlist,foodlist_msg())

    return true
end

function service.resp.leave(source,playerid)
    if not balls[playerid] then
        return false
    end
    balls[playerid]=nil
    if not leaderboard.del(service.name,playerid) then
        skynet.error("del player failed from leaderboard!")
    end
    local leavemsg ={cmd="leave",result=1,info=playerid.."离开游戏"}
    leavemsg = proto.server_encode(service.msgtype.system,leavemsg)
    broadcast(leavemsg,service.msgtype.system)
end


function service.resp.shift(source,playerid,x,y)
    local b = balls[playerid]
    if not b then 
        return false
    end
    for i , v in pairs(b) do 
        v.speedx=x
        v.speedy=y
    end
end



function service.resp.fenlie(source,playerid)
    local b = balls[playerid]
    if not b then 
        return false
    end
    for i , v in pairs(b) do 
        if v.speedx == 0 and  v.speedy == 0 then
            local m={
                playerid =v.playerid,
                node=v.node,
                agent=v.agent,
                x = v.x+v.size/2,
                y = v.y,
                size=v.size/2,
                speedx = v.speedx,
                speedy = v.speedy,
            }
        else
            local m={
                playerid =v.playerid,
                node=v.node,
                agent=v.agent,
                x = v.x+(v.size/2)*v.speedx,
                y = v.y+(v.size/2)*v.speedy,
                size=v.size/2,
                speedx = v.speedx,
                speedy = v.speedy,
            }
        end
        v.size = v.size/2
        table.insert(b,m)
    end
end


function move_update()
    for i , v in pairs(balls) do 
        for j, k in pairs(v) do
            k.x=k.x+k.speedx*0.2
            k.y=k.y+k.speedy*0.2
            if k.speedx  ~= 0 or k.speedy ~=0 then
                local msg ={cmd="move",result=1,info="player_id:"..k.playerid..", ".."player_x:"..k.x..", ".."player_y:"..k.y..", ".."\r\n"}
                msg = proto.server_encode(service.msgtype.system,msg)
                broadcast(msg,service.msgtype.system)
            end
        end
    end
end

function food_update()
    if food_count>50 then 
        return 
    end

    if math.random(0,100)>90 then
        food_count=food_count+1
        food_maxid=food_maxid+1
        local f = food()
        f.id=food_maxid
        foods[f.id]=f

        local msg ={cmd="addfood",food_id=f.id,food_x=f.x,food_y=f.y}
        msg = proto.server_encode(service.msgtype.food.foods,msg)
        broadcast(msg,service.msgtype.food.foods)
    end

end

function eat_update()
    for pid, b in pairs(balls) do
        for i, v in pairs(b) do 
            for fid , f in pairs(foods) do
                if (v.x-f.x)^2+(v.y-f.y)^2<v.size^2 then
                    v.size=v.size+1
                    food_count=food_count-1
                    if not leaderboard.update_score(service.name,v.playerid,v.size) then
                        skynet.error("update_score player failed to leaderboard!")
                    end
                    local msg ={cmd="eat",result=1,info="玩家"..v.playerid.."吃掉食物"..fid.."后分数为"..v.size}
                    msg = proto.server_encode(service.msgtype.system,msg)
                    broadcast(msg,service.msgtype.system)
                    foods[fid]=nil
                end
            end
        end
    end
end

--更新排行榜
function board_update()
    local ok=leaderboard.get_top_players(service.name,5)

    if not ok then 
        skynet.error("Failed get_top_players!")
        return 
    elseif #ok == 0 then 
        skynet.error("leaderboard no man!")
        return 
    end
    ---[[
    local buff ={}
    local leaderboard={}
    for i, v in ipairs(ok) do 
        local msg ={player_id=v.player_id,score=v.score,rank=v.rank}
        table.insert(leaderboard,msg)
    end
    buff.leaderboard=leaderboard
    local proto_msg = proto.server_encode(service.msgtype.leader,buff)
    broadcast(proto_msg,service.msgtype.leader)
    --]]

end

function update(frame)
    food_update()
    move_update()
    eat_update()  
    --board_update()
end

function service.init()
    leaderboard.init_redis()
    pb.register_file("./proto/Sc_Login.pb")
    pb.register_file("./proto/Cs_Login.pb")
    pb.register_file("./proto/Cs_EnterRoom.pb")
    pb.register_file("./proto/player.pb")
    pb.register_file("./proto/food.pb")
    pb.register_file("./proto/leader.pb")
    skynet.fork(function()
        local stime = skynet.now()
        local frame = 0
        while true do
            frame = frame+1
            local isok,err =pcall(update,frame)
            if not isok then 
                skynet.error(err)
            end
            local etime = skynet.now()
            local waittime =frame*10 - (etime - stime)
            --测试print("frame: "..frame.." waittime: "..waittime)
            if waittime <= 0 then 
                waittime =2
            end
            skynet.sleep(waittime)
            if frame>=10000000 then
                frame=0
                stime =skynet.now()
            end
        end
    end)
    skynet.fork(function()
        local stime = skynet.now()
        local frame = 0
        while true do
            frame = frame+1
            local isok,err =pcall(board_update)
            if not isok then 
                skynet.error(err)
            end
            local etime = skynet.now()
            local waittime =frame*1000 - (etime - stime)
            --测试print("frame: "..frame.." waittime: "..waittime)
            if waittime <= 0 then 
                waittime =2
            end
            skynet.sleep(waittime)
            if frame>=10000000 then
                frame=0
                stime =skynet.now()
            end
        end
    end)
end

service.start(...)