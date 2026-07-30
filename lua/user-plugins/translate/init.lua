-- 自定义翻译插件
-- 依赖: llama.cpp + llama-server + Hy-MT2 翻译模型
-- 操作:
--   <leader>at  翻译选中/全文到侧栏 scratch buffer
--   <leader>aT  翻译选中/全文并替换当前 buffer

local M = {}

-- ====== 常量 ======

local CONFIG = {
    llama_cpp_dir = vim.fn.expand("~/llama.cpp/build"),
    port = 9999,
    host = "127.0.0.1",
    model = vim.fn.expand("~/models/") .. "Hy-MT2-1.8B-Q4_K_M.gguf",
}

local api_url = string.format("http://%s:%d/v1/chat/completions", CONFIG.host, CONFIG.port)
local health_url = string.format("http://%s:%d/health", CONFIG.host, CONFIG.port)

-- ====== 状态 ======

local server_obj = nil
local server_ready = false

-- ====== 服务管理 ======

--- 确保 llama-server 正在运行
---@param cb function 就绪后回调
local function ensure_server(cb)
    if server_ready then return cb() end

    if not server_obj then
        local bin = CONFIG.llama_cpp_dir .. "/bin/llama-server"
        if vim.fn.executable(bin) ~= 1 then
            vim.notify(
                "llama-server not found at " .. bin .. "\nRun: nvim/scripts/llama-translate.sh",
                vim.log.levels.ERROR
            )
            return
        end

        server_obj = vim.system({
            bin,
            "-m", CONFIG.model,
            "-ngl", "99",
            "--port", tostring(CONFIG.port),
            "--host", CONFIG.host,
        }, { detach = true }, function()
            server_obj = nil
            server_ready = false
        end)
    end

    local max_attempts = 30
    local attempts = 0

    local function poll()
        attempts = attempts + 1
        if attempts > max_attempts then
            vim.notify("llama-server failed to start", vim.log.levels.ERROR)
            return
        end

        vim.system({ "curl", "-s", health_url }, { text = true }, function(r)
            if r.code == 0 and r.stdout and r.stdout:find('"ok"') then
                server_ready = true
                cb()
            else
                vim.defer_fn(poll, 300) -- 300ms
            end
        end)
    end
    poll()
end

-- 退出时杀掉 llama-server
vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        if server_obj then
            server_obj:kill("sigterm")
        end
    end,
})

-- ====== 翻译 API ======

--- 异步翻译文本
---@param text string
---@param target string "en"|"zh"
---@param cb fun(result: string|nil)
local function translate(text, target, cb)
    local lang = target == "zh" and "Chinese" or "English"
    local prompt = string.format("Translate to %s:\n%s", lang, text)
    local payload = vim.json.encode({
        model = "hy-mt2",
        messages = { { role = "user", content = prompt } },
        temperature = 0.1,
        max_tokens = 8192,
    })

    vim.system({
        "curl", "-s", "-X", "POST", api_url,
        "-H", "Content-Type: application/json",
        "-d", payload,
    }, { text = true }, function(r)
        if r.code ~= 0 then
            vim.notify("curl failed: " .. (r.stderr or "unknown"), vim.log.levels.ERROR)
            return cb(nil)
        end
        local ok, decoded = pcall(vim.json.decode, r.stdout)
        if not ok or not decoded.choices or not decoded.choices[1] then
            vim.notify("Translation API: unexpected response", vim.log.levels.ERROR)
            return cb(nil)
        end
        cb(decoded.choices[1].message.content)
    end)
end

-- ====== 文本获取 ======

--- 获取当前 buffer 全文
local function get_buffer_text()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    return table.concat(lines, "\n")
end

--- 获取最近一次 visual 选区的文本（来自 '<,'> 标记）
local function get_visual_text()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    if start_pos[2] == 0 and end_pos[2] == 0 then return nil end
    local lines = vim.fn.getregion(start_pos, end_pos, { type = vim.fn.visualmode() })
    return table.concat(lines, "\n")
end

-- ====== UI 操作 ======

--- 操作 1: 翻译到侧栏 scratch buffer
---@param from_visual boolean 是否来自 visual 模式
function M.split(from_visual)
    local text = from_visual and get_visual_text() or get_buffer_text()
    if not text or text == "" then
        return vim.notify("No text to translate", vim.log.levels.WARN)
    end

    local target = vim.fn.input("Translate to (en/zh): ", "zh")
    if target == "" then return end
    target = target:lower()
    if target ~= "en" and target ~= "zh" then
        return vim.notify("Invalid language. Use en or zh.", vim.log.levels.WARN)
    end

    ensure_server(function()
        translate(text, target, function(result)
            if not result then
                vim.notify("✗ Translation failed", vim.log.levels.ERROR)
                return
            end

            -- 创建侧栏 scratch buffer
            vim.cmd("vsplit")
            vim.cmd("enew")
            local buf = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_name(buf, "Translation")
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].modified = false

            local lines = vim.split(result, "\n", { plain = true })
            if lines[#lines] == "" then table.remove(lines) end
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].modified = false

            vim.notify("✓ Translated (" .. target .. ")", vim.log.levels.INFO)
        end)
    end)
end

--- 操作 2: 翻译并替换当前 buffer
---@param from_visual boolean 是否来自 visual 模式
function M.replace(from_visual)
    local text = from_visual and get_visual_text() or get_buffer_text()
    if not text or text == "" then
        return vim.notify("No text to translate", vim.log.levels.WARN)
    end

    local target = vim.fn.input("Translate to (en/zh): ", "zh")
    if target == "" then return end
    target = target:lower()
    if target ~= "en" and target ~= "zh" then
        return vim.notify("Invalid language. Use en or zh.", vim.log.levels.WARN)
    end

    local buf = vim.api.nvim_get_current_buf()
    vim.notify("⏳ Translating...", vim.log.levels.INFO)

    ensure_server(function()
        translate(text, target, function(result)
            if not result then
                vim.notify("✗ Translation failed", vim.log.levels.ERROR)
                return
            end

            local lines = vim.split(result, "\n", { plain = true })
            if lines[#lines] == "" then table.remove(lines) end

            if from_visual then
                local sr = vim.fn.line("'<")
                local er = vim.fn.line("'>")
                if sr > er then sr, er = er, sr end
                vim.api.nvim_buf_set_lines(buf, sr - 1, er, false, lines)
            else
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            end
            vim.bo[buf].modified = true

            vim.notify("✓ Translated " .. #lines .. " lines (" .. target .. ")", vim.log.levels.INFO)
        end)
    end)
end

function M.close()
    if server_obj then
        server_obj:kill("sigterm")
        server_obj = nil
        server_ready = false
        vim.notify("llama-server stopped", vim.log.levels.INFO)
    else
        vim.notify("llama-server is not running", vim.log.levels.WARN)
    end
end

vim.api.nvim_create_user_command("CloseTranslateLLama", function()
    M.close()
end, {})

return M
