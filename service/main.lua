local skynet =require "skynet"
local runconfig =require "runconfig"
local cluster = require "skynet.cluster"
local skynet_manager = require "skynet.manager"

skynet.start(function()
    --初始化
	local mynode = skynet.getenv("node")
	local nodecfg = runconfig[mynode]

    cluster.reload(runconfig.cluster)
	cluster.open(mynode)

    skynet.error("[main service start!]")

    
    local nodemgr=skynet.newservice("nodemgr","nodemgr",1)
    skynet.name("nodemgr",nodemgr)

	for i, v in pairs(nodecfg.login or {})  do
        local srv = skynet.newservice("login","login", i)
            skynet.name("login"..i, srv)
    end

    local anode = runconfig.agentmgr.node
    if mynode==anode then
        local agentmgr=skynet.newservice("agentmgr","agentmgr",1)
        skynet.name("agentmgr",agentmgr)
    else
        local proxy=cluster.proxy(anode,"agentmgr")
        skynet.name("agentmgr",proxy)
    end



    for _, v in pairs(runconfig.scene[mynode] or {}) do 
        local srv = skynet.newservice("scene","scene",v)
        skynet.name("scene"..v,srv)
    end

    for i, v in pairs(nodecfg.gateway or {})  do
        local srv = skynet.newservice("gateway","gateway", i)
            skynet.name("gateway"..i, srv)
    end

    skynet.exit()
end)