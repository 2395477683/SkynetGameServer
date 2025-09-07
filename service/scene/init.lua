local service = require "service"
local skynet = require "skynet"

local balls = {}
local foods={}
local food_maxid=0
local food_count=0

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

local function balllist_msg()
    local msg={"balllist"}
    for i , v in pairs(balls) do 
        for j, k in pairs(v) do 
        table.insert(msg,k.playerid)
        table.insert(msg,k.x)
        table.insert(msg,k.y)
        table.insert(msg,k.size)
        end
    end
    return msg
end

local function food()
    local m={
        id=nil,
        x=math.random(0,100),
        y=math.random(0,100)
    }
    return m
end


local function foodlist_msg()
    local msg = {"foodlist"}
    for i , v in pairs(foods) do
        table.insert(msg,v.id)
        table.insert(msg,v.x)
        table.insert(msg,v.y)
    end
    return msg
end


function broadcast(msg)
    for i , v in pairs(balls) do
        service.send(v[1].node,v[1].agent,"send",msg)
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
    local entermsg = {"enter",playerid,b[1].x,b[1].y,b[1].size}
    broadcast(entermsg)
    --记录
    balls[playerid]=b
    --[[测试
    print("测试 :"..playerid)
    print(balls[playerid])
    --]]
    --回应客户端
    local ret_msg={"enter",0,"进入游戏！"}
    --发送游戏信息
    service.send(b[1].node,b[1].agent,"send",ret_msg)
    service.send(b[1].node,b[1].agent,"send",balllist_msg())
    service.send(b[1].node,b[1].agent,"send",foodlist_msg())

    return true
end

function service.resp.leave(source,playerid)
    if not balls[playerid] then
        return false
    end
    balls[playerid]=nil
    local leavemsg ={"leave",playerid}

    broadcast(leavemsg)
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
                local msg ={"move",k.playerid,k.x,k.y}
                broadcast(msg)
            end
        end
    end
end

function food_update()
    if food_count>50 then 
        return 
    end

    if math.random(0,100)>96 then
        food_count=food_count+1
        food_maxid=food_maxid+1
        local f = food()
        f.id=food_maxid
        foods[f.id]=f

        local msg ={"addfood",f.id,f.x,f.y}
        broadcast(msg)
    end

end

function eat_update()
    for pid, b in pairs(balls) do
        for i, v in pairs(b) do 
            for fid , f in pairs(foods) do
                if (v.x-f.x)^2+(v.y-f.y)^2<v.size^2 then
                    v.size=v.size+1
                    food_count=food_count-1
                    local msg ={"eat",v.playerid,fid,v.size}
                    broadcast(msg)
                    foods[fid]=nil
                end
            end
        end
    end
end

function update(frame)
    food_update()
    move_update()
    eat_update()
end

function service.init()
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
            local waittime =frame*2 - (etime - stime)
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