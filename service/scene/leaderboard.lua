local skynet = require "skynet"
local redisHc = require "redisHc"
--local cjson =require "cjson"

local M={}
local redis_conn
local leaderboard_key = "leaderboard:global"

--初始化redis连接
function M.init_redis()
    redisHc.Hcinit()
    print("A")
    redis_conn = redisHc.get_conn()
end

--更新玩家分数
function M.update_score(player_id,size)
    local ok, err = redis_conn:zadd(leaderboard_key,size, "player:" .. player_id)
    if not ok then
        skynet.error("Failed to update leaderboard: ", err)
        return false
    end
    return true
end

--获取前n名玩家
function M.get_top_players(n)
    local result,err =redis_conn:zrevrange(leaderboard_key,0,n-1,"withscores")
    if not result then
        skynet.error("Failed to get top players: ", err)
        return {}
    end

    local players={}
    for i = 1, #result, 2 do
        local member = result[i]
        local score = tonumber(result[i+1])
        local player_id = string.match(member, "player:(%d+)")
        
        table.insert(players, {
            rank = math.floor((i-1)/2) + 1,
            player_id = tonumber(player_id),
            score = score
        })
    end
    return players
end

--获取玩家排名和分数
function M.get_player_rank(player_id)
    local member = "player:" .. player_id
    
    --使用管道一次性获取排名和分数
    redis_conn:init_pipeline()
    redis_conn:zrevrank(leaderboard_key, member)
    redis_conn:zscore(leaderboard_key, member)
    local results, err = redis_conn:commit_pipeline()
    
    local rank = results[1]
    local score = tonumber(results[2])
    
    return rank + 1, score --排名从0开始，所以+1
end


return M