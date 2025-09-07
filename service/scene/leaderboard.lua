local skynet = require "skynet"
local redisHc = require "redisHc"
local cjson =require "cjson"

local redis_conn
local leaderboard_key = "leaderboard:global"