local skynet = require "skynet"
local s = require "service"
local lfs = require "lfs"
local log = require "log"

local log_path = skynet.getenv("self_logpath")
local is_debug = skynet.getenv("self_logdebug") == "true"

local _current_file = nil

local function check_exists(path)
    local attr = lfs.attributes(path)
    if not attr then
        lfs.mkdir(path)
        log.info(string.format("logger check_exists and create path:%s", path))
    elseif attr.mode ~= "directory" then
        log.info(string.format("logger check_exists, exists but is not a directory. path:%s", path))
    end
end

local function full_file(file_name)
    return log_path .. file_name
end

local function new_file()
    local timestamp = math.floor(skynet.time())
    local current_time = os.date("*t", timestamp)

    local formatted_time =
        string.format(
        "%04d%02d%02d%02d%02d",
        current_time.year,
        current_time.month,
        current_time.day,
        current_time.hour,
        current_time.min
    )
    local file_name = formatted_time .. ".log"

    local file, err = io.open(full_file(file_name), "a")

    log.info(string.format("logger new_file end. file_name:%s err:%s", file_name, err))
    return file
end

-- 避免无限生成文件
local function checkfix_file_count()
    if is_debug then
        return
    end

    local oldest_file = ""
    local file_count = 0
    for file_name in lfs.dir(log_path) do
        if file_name ~= "." and file_name ~= ".." then
            local file_path = full_file(file_name)
            local mode = lfs.attributes(file_path, "mode")

            if mode == "file" then
                local oldest_num = tonumber(oldest_file) or 999999999999
                local cur_file = file_name:match("(.*)%.log$")
                local cur_num = tonumber(cur_file)

                if cur_num < oldest_num then
                    oldest_file = cur_file
                end
                file_count = file_count + 1
            end
        end
    end

    log.info(string.format("logger checkfix_file_count end. oldest_file:%s file_count:%s", oldest_file, file_count))

    if file_count > 200 then
        os.remove(full_file(oldest_file))

        log.info(string.format("logger checkfix_file_count remove fail. oldest_file:%s file_count:%s", oldest_file, file_count))
    end
end

local function time_file()
    if _current_file ~= nil then -- 文件正在写入中会导致关闭失败，资源得不到释放？Todo zhangzhihui
        _current_file:close()
    end

    local oldest_file = _current_file

    local file = new_file()
    if  file then
        _current_file = file
    end

    log.info(string.format("logger time_file, choice new file. oldest_file:%s new_file:%s", oldest_file, _current_file))

    checkfix_file_count()

    -- 每5分钟创建一个新文件
    skynet.timeout(_G.SKYNET_MINUTE * 5, time_file)
end

function s.resp.logging(source, str)
    if not _current_file then
        return
    end

    _current_file:write(str .. "\n")
    _current_file:flush()
end

-- 服务退出
function s.resp.srv_exit(srcaddr)
    skynet.exit()
end

s.initfunc = function()
    require "common_def"

    check_exists(log_path)

    time_file()
end

s.start(...)