# 球球大作战游戏服务器 (SkynetGameServer)

[![Skynet](https://img.shields.io/badge/Skynet-1.6.0-blue)](https://github.com/cloudwu/skynet)
[![Redis](https://img.shields.io/badge/Redis-6.0+-red)](https://redis.io/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-blue)](https://www.mysql.com/)
[![Protobuf](https://img.shields.io/badge/Protobuf-3.0+-green)](https://github.com/protocolbuffers/protobuf)
[![Lua](https://img.shields.io/badge/Lua-5.4+-yellow)](https://www.lua.org/)

基于Skynet框架开发的分布式游戏服务器，实现类似球球大作战的多人在线实时对战游戏。使用Redis作为缓存层，MySQL作为持久化存储，Protobuf进行网络序列化。

## 📖 目录

- [项目概述](#-项目概述)
- [架构设计](#-架构设计)
- [功能特性](#-功能特性)
- [快速开始](#-快速开始)
- [项目结构](#-项目结构)
- [配置说明](#-配置说明)
- [协议格式](#-协议格式)
- [API文档](#-api文档)
- [开发指南](#-开发指南)
- [部署指南](#-部署指南)
- [贡献指南](#-贡献指南)
- [许可证](#-许可证)

## 🎯 项目概述

这是一个基于Skynet框架开发的分布式游戏服务器，实现了类似球球大作战的游戏逻辑。服务器采用多节点分布式架构，支持高并发玩家同时在线，具备良好的扩展性和稳定性。

## 🏗 架构设计

### 系统架构
```
客户端 → 网关服务器 → 登录服务器 → 游戏大厅 → 游戏房间
                     ↓          ↓           ↓
                  Redis缓存 ← 数据库代理 → MySQL存储
```

### 核心服务
- **网关服务(Gate)**: 处理客户端连接，消息编解码和转发
- **登录服务(Login)**: 处理用户认证和会话管理
- **大厅服务(Hall)**: 管理房间列表和玩家匹配
- **房间服务(Room)**: 处理游戏核心逻辑和状态同步
- **数据库代理(DB)**: 统一数据存取接口，缓存策略管理
- **监控服务(Monitor)**: 系统状态监控和日志收集

### 数据流
1. 客户端通过WebSocket连接网关服务器
2. 网关使用Protobuf进行消息编解码
3. 登录验证通过后，用户进入大厅
4. 大厅服务负责匹配玩家并创建房间
5. 房间内游戏状态通过网关广播给客户端
6. 游戏数据定期持久化到MySQL，Redis作为缓存加速读写

## ✨ 功能特性

- **玩家系统**: 注册、登录、个人资料管理
- **房间系统**: 创建房间、自动匹配、房间管理
- **游戏逻辑**: 球体移动、吞噬成长、食物生成
- **实时同步**: 状态同步、位置预测、延迟补偿
- **数据持久化**: 玩家数据、游戏记录、排行榜
- **扩展功能**: 聊天系统、好友系统、成就系统

## 🚀 快速开始

### 环境要求
- Linux/Unix 系统 (推荐 Ubuntu 18.04+)
- Skynet 1.6.0+
- Redis 6.0+
- MySQL 8.0+
- Protobuf 3.0+
- Lua 5.4+

### 安装步骤

1. 克隆项目
```bash
git clone https://github.com/2395477683/SkynetGameServer.git
cd SkynetGameServer
```

2. 安装依赖
```bash
# 安装系统依赖
sudo apt-get install automake autoconf libtool build-essential 
sudo apt-get install libreadline-dev git

# 安装Skynet
make skynet

# 安装Lua依赖库
make lualib
```

3. 安装并配置数据库
```bash
# 安装MySQL和Redis
sudo apt-get install mysql-server redis-server

# 初始化数据库
mysql -u root -p < sql/init.sql
```

4. 编译Protobuf协议
```bash
cd proto
make
```

5. 启动服务器
```bash
# 启动主节点
./skynet/skynet config/config.game

# 启动网关节点
./skynet/skynet config/config.gate
```

## 📁 项目结构

```
SkynetGameServer/
├── skynet/                 # Skynet框架
├── lualib/                 # Lua库文件
│   ├── proto/              # Protobuf生成的Lua代码
│   ├── cluster.lua         # 集群管理
│   └── ...                 # 其他工具库
├── service/                # Skynet服务
│   ├── gate.lua            # 网关服务
│   ├── login.lua           # 登录服务
│   ├── hall.lua            # 大厅服务
│   ├── room.lua            # 房间服务
│   ├── db_agent.lua        # 数据库代理
│   └── monitor.lua         # 监控服务
├── proto/                  # Protobuf协议定义
│   ├── message.proto       # 通信协议
│   ├── struct.proto        # 数据结构
│   └── Makefile           # 编译脚本
├── config/                 # 配置文件
│   ├── config.game         # 游戏服务器配置
│   ├── config.gate         # 网关配置
│   ├── config.login        # 登录服务器配置
│   └── config.room         # 房间服务器配置
├── sql/                    # 数据库脚本
│   ├── init.sql            # 初始化数据库
│   └── update.sql          # 数据库更新脚本
├── test/                   # 测试代码
│   ├── unit_test/          # 单元测试
│   └── pressure_test/      # 压力测试
├── tools/                  # 工具脚本
├── Makefile               # 项目构建文件
└── README.md              # 项目说明
```

## ⚙️ 配置说明

配置文件位于`config/`目录下，主要配置项包括：

### 游戏服务器配置 (config.game)
```lua
-- 基本配置
thread = 8
logger = nil
harbor = 0
address = "127.0.0.1:2526"
master = "127.0.0.1:2013"
standalone = "0.0.0.0:2013"

-- 数据库配置
redis_host = "127.0.0.1"
redis_port = 6379
redis_db = 0
mysql_host = "127.0.0.1"
mysql_port = 3306
mysql_database = "ball_game"
mysql_user = "root"
mysql_password = "password"

-- 游戏配置
max_room_count = 1000      -- 最大房间数
max_player_per_room = 50   -- 每个房间最大玩家数
room_timeout = 1800        -- 房间超时时间(秒)
```

### 网关配置 (config.gate)
```lua
-- 网络配置
gate_port = 8001           -- 网关端口
max_client = 10000         -- 最大连接数
socket_timeout = 60        --  socket超时时间(秒)

-- 协议配置
proto_path = "../lualib/proto"  -- Protobuf协议路径
```

## 📡 协议格式

使用Protobuf定义通信协议，主要消息类型包括：

### 登录协议
```protobuf
// 登录请求
message CS_Login {
    string username = 1;
    string password = 2;
}

// 登录响应
message SC_Login {
    int32 code = 1;
    string message = 2;
    PlayerInfo player = 3;
}
```

### 房间协议
```protobuf
// 进入房间请求
message CS_EnterRoom {
    int32 room_id = 1;
}

// 进入房间响应
message SC_EnterRoom {
    int32 code = 1;
    string message = 2;
    RoomInfo room = 3;
}

// 玩家移动
message CS_Move {
    float direction_x = 1;
    float direction_y = 2;
    float speed = 3;
}

// 广播玩家移动
message SC_Move {
    int32 player_id = 1;
    float position_x = 2;
    float position_y = 3;
}
```

## 📋 API文档

### 网关API
- `gate.open(port, maxclient)` - 打开网关监听端口
- `gate.forward(source, fd, message)` - 转发消息到客户端
- `gate.close(fd)` - 关闭客户端连接

### 数据库API
- `db_agent.set(key, value)` - 设置缓存数据
- `db_agent.get(key)` - 获取缓存数据
- `db_agent.query(sql)` - 执行SQL查询
- `db_agent.execute(sql)` - 执行SQL更新

### 房间API
- `room.create(config)` - 创建新房间
- `room.join(room_id, player)` - 加入房间
- `room.leave(room_id, player_id)` - 离开房间
- `room.broadcast(room_id, message)` - 广播消息到房间

## 🛠 开发指南

### 添加新服务
1. 在`service/`目录下创建新的Lua文件
2. 实现服务的初始化方法和消息处理函数
3. 在配置文件中添加服务启动配置
4. 更新协议文件定义新的消息类型

### 添加新协议
1. 在`proto/`目录下的.proto文件中定义新消息
2. 运行`make`重新生成Lua协议代码
3. 在相应服务中实现消息处理逻辑

### 测试流程
```bash
# 运行单元测试
make test

# 运行压力测试
make pressure_test

# 检查代码规范
make lint
```

## 📦 部署指南

### 生产环境部署
1. 配置服务器环境变量
2. 设置数据库连接参数
3. 配置日志和监控系统
4. 使用进程管理工具(如systemd)管理服务

### 集群部署
1. 修改集群配置中的节点地址
2. 配置负载均衡器
3. 设置数据库主从复制
4. 配置Redis集群

### 监控和日志
- 使用Prometheus监控系统指标
- 使用Grafana展示监控数据
- 日志集中收集到ELK栈

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 开发流程
1. Fork本项目
2. 创建特性分支: `git checkout -b feature/AmazingFeature`
3. 提交更改: `git commit -m 'Add some AmazingFeature'`
4. 推送分支: `git push origin feature/AmazingFeature`
5. 提交Pull Request

### 代码规范
- 遵循Lua代码风格指南
- 使用有意义的变量和函数名
- 添加必要的注释和文档
- 编写单元测试覆盖新功能

## 📄 许可证

本项目基于MIT许可证开源，详见[LICENSE](LICENSE)文件。

## 🙏 致谢

- 感谢[Skynet](https://github.com/cloudwu/skynet)提供的优秀游戏服务器框架
- 感谢所有贡献者和用户的支持
- 灵感来源于经典的球球大作战游戏

---

⭐ 如果这个项目对你有帮助，请给它一个star！
