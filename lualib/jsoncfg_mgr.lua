-- 加载json数据并添加到内存管理
local json = require "cjson"
local lfs = require "lfs"
local cfgmgr = require "jsoncfg_def"
local log = require "log"

local directory_path = "./config/server_json/"

local function load_jsoncfg(filename)
    log.info("load json start...: " .. filename)

    local cfgname = filename:match("/([^/]+)%.json$")
    if cfgmgr[cfgname] == nil then
        return
    end

    local file = io.open(filename, "r")
    assert(file ~= nil)
    local items = json.decode(file:read("*all"))
    file:close()

    local new = {}
    for _, item in ipairs(items) do
        if item and next(item) ~= nil then
            new[item.ID] = item
        end
    end

    cfgmgr[cfgname].items = new
end

local function traverse_directory(path)
    for file_name in lfs.dir(path) do
        if file_name ~= "." and file_name ~= ".." then
            local file_path = path .. file_name
            local mode = lfs.attributes(file_path, "mode")

            if mode == "file" then
                load_jsoncfg(file_path)
            elseif mode == "directory" then
                traverse_directory(file_path)
            end
        end
    end
end

traverse_directory(directory_path)

-- 为每个mgr绑定基础的查找方法
local function bind_find_func()
    for _, cfg in pairs(cfgmgr) do
        local tmp = cfg -- 创建一个新的局部变量捕获当前迭代的 tbl 值
        if tmp then
            tmp.find_item = function(id)
                if not tmp.items then
                    return nil
                end
                return tmp.items[id]
            end
        end
    end
end

bind_find_func()

-- 添加自己的自定义方法onloadpost

-- function cfgmgr.CfgAchievement:onloadpost()
--     local items_hash = {}
--     for id, value in ipairs(self.items) do
--         items_hash[id * 1000] = value
--     end
--     self.items_hash = items_hash
-- end

-- function cfgmgr.CfgAchievement:find_by_hash(id)
--     local hash = id * 1000
--     return self.items_hash[hash]
-- end

--

local function onloadpost()
    for _, value in pairs(cfgmgr) do
        if type(value) == "table" and type(value.onloadpost) == "function" then
            value:onloadpost()
        end
    end
end

onloadpost()

return cfgmgr
