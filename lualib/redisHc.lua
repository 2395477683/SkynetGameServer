local redis = require "redis"
local service = require "service"
local skynet = require "skynet"
local proto =require "proto"
local pb = require "protobuf"
--local cjson = require "cjson"

local M = {}
local pool = {}
local conn_count = 5 --连接池大小
local NAMESPACE = "player"


 -- 初始化
function M.Hcinit()
    for i = 1, conn_count do 
        local redisc = redis.connect({host = "127.0.0.1",port = 6379,db=0 })
        table.insert(pool,redisc)
    end
    pb.register_file("./proto/Mysql.pb")
end

 -- 简单的连接池实现
function M.get_conn()
    local idx = math.random(1,#pool)
    return pool[idx]
end

-- 生成Redis键名
function M.make_key(namespace,id)
    return string.format("%s:%s",namespace,id)
end

-- 从缓存获取数据
function M.get(type,namespace,id)
    local conn = M.get_conn()
    local key = M.make_key(NAMESPACE..namespace,id)
    if type == "string" then 
        local data,err = conn:get(key)

        if data and data ~= "unknown" then 
            skynet.error("Cash HIT for",key)
            return data
        else
            skynet.error("Cash MISS for",key)
            return nil
        end

    elseif type == "list" then
        local data,err = conn:lrange(key,0,-1)
    
        if data and data ~= "unknown" and #data>0  then        --可能返回空表
            skynet.error("Cash HIT for",key)
            return data
        else
            skynet.error("Cash MISS for",key)
            return nil
        end
    end
end

--从缓存删除数据
function M.del_list(namespace,id)
    local conn = M.get_conn()
    local key = M.make_key(NAMESPACE..namespace,id)

    local data,err = conn:lpop(key)

    return true
end

-- 设置缓存数据(字符串)，带过期时间
function M.set(type,namespace,id,data,ttl)
    local conn = M.get_conn()
    local key = M.make_key(NAMESPACE..namespace,id)

    if type == "string" then
        if ttl then 
            ok,err =conn:setex(key,ttl,data)
        else
            ok,err=conn:set(key,data)
        end

        if not ok then
            skynet.error("Failed to set cache: ",err)
        end 
        return true

    elseif type =="list" then
        local ok,err=conn:rpush(key,data)
        if not ok then
            skynet.error("Failed to set list cache: ",err)
        end

        if ttl then 
            local isok,err = conn:expire(key,ttl)
            if not isok then
                skynet.error("Failed to set list ttl: ",err)
            end
        end 
        return true
    end
end

--删除缓存
function M.invalidate(type,namespace,id)
    local conn = M.get_conn()
    local key = M.make_key(NAMESPACE..namespace,id)

    if type == "string" then
        local ok ,err = conn:del(key)

        if not ok then 
            skynet.error("Failed to invalidate cache : ",err)
            return false
        end
        return true

    elseif type == "list" then
        local ok ,err = conn:del(key)
    
        if not ok then 
            skynet.error("Failed to invalidate cache : ",err)
            return false
        end
        return true
    end
end


--获取玩家数据
function M.get_player(type,namespace,player_id)
    --尝试从缓存获取
    local cached_data = M.get(type,namespace,player_id)
    if cached_data then
        return cached_data
    end

    skynet.error("Cache miss for player:",player_id,",querying MySQL...")

    if type == "string" then 
        --缓存未命中，从数据库获取
        local res = db:query("SELECT * FROM user WHERE playerid = " .. player_id)
        if #res ~= 0 then      
        res = proto.server_encode(service.msgtype.mysql.user,res[1])
        end

        if not res then
            --防止缓存穿透,即使不存在也缓存值
            local unknown = "unknown"
            M.set(type,namespace,player_id, unknown, 300) --5分钟
            return nil
        end

        --回填缓存
        M.set(type,namespace,player_id, res, 3600) --1小时
        return res
    elseif type == "list" then
        --缓存未命中，从数据库获取
        local res = db:query("SELECT friend_id FROM friendships WHERE user_id = " .. player_id)
        local result_table = {}
        if #res ~= 0 then      
            for i , v in ipairs (res) do
                local proto_v = proto.server_encode(service.msgtype.mysql.friend,v)
                result_table[i]  =  proto_v
            end
        end

        if not res then
            --防止缓存穿透,即使不存在也缓存值
            local unknown = "unknown"
            M.set(type,namespace,player_id,unknown, 300) --5分钟
            return nil
        end

        --回填缓存
        for i , v in ipairs(result_table) do
            M.set(type,namespace,player_id, v, 3600) --1小时
        end
        return result_table

    end
end

--更新玩家数据
function M.update_player(player_id,updates)
    --构建更新sql
    local set_parts = {}
    for k, v in pairs(updates) do
        table.insert(set_parts,k.." = '"..v.."'")
    end
    local set_clause = table.concat(set_parts,",")

    --更新数据库
    local ok ,err = db:query("UPDATE user SET "..set_clause .. " WHERE playerid = "..player_id)
    if not ok then 
        return false ,"MySQL update failed : "..err
    end

    --使旧缓存失效
    M.invalidate("",player_id)

    --更新缓存
    local res = db:query("SELECT * FROM user WHERE playerid = " .. player_id)
    if #res ~= 0 then
       res = proto.server_encode(service.msgtype.mysql.user,res[1])
    end
    M.set("string","",player_id, res, 3600) --1小时
    return true
end 

function M.more_get_players(player_ids)
    local results ={}
    local missing_ids ={}

    --批量从缓存中获取
    for _, id in ipairs(player_ids) do 
        local cached =M.get(NAMESPACE,id)
        if cached then
            if not cached.__not_found then 
                results[id] =cachedend
            else
                table.insert(missing_ids,id)
            end
        end
    end

    --如果有未命中的，从数据库批量查询
    if #missing_ids > 0 then
        local id_list = table.concat(missing_ids, ",")
        local res = db:query("SELECT * FROM players WHERE id IN (" .. id_list .. ")")
        
        --处理查询结果并回填缓存
        for _, row in ipairs(res) do
            results[row.id] = row
            M.set(row.id, row, 3600)
        end
        
        --处理不存在的ID（防止缓存穿透）
        for _, id in ipairs(missing_ids) do
            if not results[id] then
                M.set(id, {__not_found = true}, 300)
            end
        end
    end
     
    return results

end

return M