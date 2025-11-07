-- voice-input/processor.lua
-- 极简版：Ctrl_R 触发，结果准备好后按任意键自动上屏

local RESULT_FILE = "/tmp/rime-voice-input-result.txt"

local function init(env)
    local config = env.engine.schema.config
    env.trigger_key = config:get_string("voice_input/trigger_key") or "Control_R"
    env.last_mtime = 0
end

local function get_file_mtime()
    local handle = io.popen("stat -c %Y " .. RESULT_FILE .. " 2>/dev/null")
    if not handle then return 0 end

    local time_str = handle:read("*line")
    handle:close()

    return tonumber(time_str) or 0
end

local function read_first_result()
    local file = io.open(RESULT_FILE, "r")
    if not file then return nil end

    local content = file:read("*all")
    file:close()

    if content and content ~= "" then
        -- 移除前后空白和换行
        return content:gsub("^%s*(.-)%s*$", "%1")
    end

    return nil
end

local function processor(key, env)
    local key_repr = key:repr()

    -- Ctrl_R 调用 voice-input-core
    if key_repr == env.trigger_key then
        os.execute("voice-input-core &")
        return 1  -- kAccepted
    end

    -- 检查是否有新结果
    local mtime = get_file_mtime()
    if mtime > env.last_mtime then
        env.last_mtime = mtime

        -- 读取第一行结果
        local result = read_first_result()
        if result then
            -- 忽略修饰键和释放事件
            if not (key_repr:match("_[LR]$") or key:release()) then
                -- 直接上屏
                env.engine:commit_text(result)

                -- 删除结果文件
                os.execute("rm -f " .. RESULT_FILE)

                return 1  -- kAccepted，消耗这个按键
            end
        end
    end

    return 2  -- kNoop
end

return { init = init, func = processor }
