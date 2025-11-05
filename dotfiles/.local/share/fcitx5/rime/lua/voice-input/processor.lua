-- voice-input/processor.lua
-- 极简版：只负责触发和上屏

local RESULT_FILE = "/tmp/rime-voice-input-result.txt"

local function init(env)
    local config = env.engine.schema.config
    env.trigger_key = config:get_string("voice_input/trigger_key") or "Control_R"
    env.last_result_time = 0
end

local function fini(env)
end

local function read_result()
    local file = io.open(RESULT_FILE, "r")
    if not file then
        return nil
    end

    local result = file:read("*all")
    local mtime = 0

    -- 获取文件修改时间
    local handle = io.popen("stat -c %Y " .. RESULT_FILE .. " 2>/dev/null")
    if handle then
        local time_str = handle:read("*line")
        handle:close()
        mtime = tonumber(time_str) or 0
    end

    file:close()

    if result and result ~= "" then
        return result:gsub("\n$", ""), mtime
    end

    return nil, 0
end

local function processor(key, env)
    local key_repr = key:repr()

    -- 检查是否有新结果需要上屏
    local result, mtime = read_result()
    if result and mtime > env.last_result_time then
        env.last_result_time = mtime

        -- 上屏结果
        env.engine:commit_text(result)

        -- 清理结果文件
        os.execute("rm -f " .. RESULT_FILE)

        -- 消耗这个按键
        return 1  -- kAccepted
    end

    -- 处理触发键
    if key_repr == env.trigger_key  then
        -- 调用 voice-input-core
        os.execute("voice-input-core &")
        return 1  -- kAccepted
    end

    return 2  -- kNoop
end

return { init = init, func = processor, fini = fini }
