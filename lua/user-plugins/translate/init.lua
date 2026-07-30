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
    model = vim.fn.expand("~/models/Hy-MT2-1.8B-Q4_K_M.gguf"),
    context = 8192,  -- 上下文长度（token），翻译够用且省显存
    idle_seconds = 600,  -- 闲置后自动卸载模型，下次请求自动重新加载
}

local api_url = string.format("http://%s:%d/v1/chat/completions", CONFIG.host, CONFIG.port)
local health_url = string.format("http://%s:%d/health", CONFIG.host, CONFIG.port)

-- ====== 工具函数 ======

local function curl_get(url, cb)
    vim.system({ "curl", "-s", url }, { text = true }, function(r)
        cb(r.code == 0 and r.stdout and r.stdout:find('"ok"'))
    end)
end

local function get_target_lang()
    local target = vim.fn.input("Translate to (en/zh): ", "zh")
    if target == "" then return nil end
    target = target:lower()
    if target ~= "en" and target ~= "zh" then
        vim.notify("Invalid language. Use en or zh.", vim.log.levels.WARN)
        return nil
    end
    return target
end

local function get_text(from_visual)
    if from_visual then
        local s = vim.fn.getpos("'<")
        local e = vim.fn.getpos("'>")
        if s[2] == 0 then return nil end
        return table.concat(vim.fn.getregion(s, e, { type = vim.fn.visualmode() }), "\n")
    end
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

-- ====== 服务管理 ======

local function poll_until_ready(cb, attempts)
    attempts = (attempts or 0) + 1
    if attempts > 30 then
        vim.notify("llama-server failed to start", vim.log.levels.ERROR)
        return
    end

    curl_get(health_url, function(ok)
        if ok then
            cb()
        else
            vim.defer_fn(function() poll_until_ready(cb, attempts) end, 300)
        end
    end)
end

local function start_server(cb)

    local bin = CONFIG.llama_cpp_dir .. "/bin/llama-server"
    if vim.fn.executable(bin) ~= 1 then
        vim.notify(
            "llama-server not found at " .. bin .. "\nRun: nvim/scripts/llama-translate.sh",
            vim.log.levels.ERROR
        )
        return
    end

    vim.system({
        bin,
        "-m", CONFIG.model,
        "-ngl", "99",
        "-c", tostring(CONFIG.context),
        "-np", "1",
        "--port", tostring(CONFIG.port),
        "--host", CONFIG.host,
        "--sleep-idle-seconds", tostring(CONFIG.idle_seconds),
    }, { detach = true })

    vim.schedule(function()
        vim.notify("llama-server starting...", vim.log.levels.INFO)
    end)

    poll_until_ready(cb)
end

local function ensure_server(cb)
    curl_get(health_url, function(ok)
        if ok then
            return cb()
        end
        start_server(cb)
    end)
end

-- ====== 翻译 API ======

local function translate(text, target, ft, cb)
    local lang = target == "zh" and "Chinese" or "English"
    local hint = ft ~= "" and string.format(" (%s source)", ft) or ""
    local prompt = string.format(
        "Translate the following%s to %s. Preserve code, markup, and formatting exactly.\n\n%s",
        hint, lang, text
    )

    vim.system({
        "curl", "-s", "--max-time", "120", "-X", "POST", api_url,
        "-H", "Content-Type: application/json",
        "-d", vim.json.encode({
            model = "hy-mt2",
            messages = { { role = "user", content = prompt } },
            temperature = 0.1,
            max_tokens = 8192,
        }),
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

-- ====== 操作 ======

function M.split(from_visual)
    local text = get_text(from_visual)
    if not text or text == "" then
        return vim.notify("No text to translate", vim.log.levels.WARN)
    end
    local target = get_target_lang()
    if not target then return end

    local ft = vim.bo.filetype

    ensure_server(function()
        translate(text, target, ft, function(result)
            vim.schedule(function()
                if not result then
                    vim.notify("✗ Translation failed", vim.log.levels.ERROR)
                    return
                end

                vim.cmd("vsplit")
                vim.cmd("enew")
                local buf = vim.api.nvim_get_current_buf()
                vim.bo[buf].buftype = "nofile"
                vim.bo[buf].bufhidden = "wipe"
                vim.bo[buf].filetype = ft
                vim.api.nvim_buf_set_name(buf, "Translation")

                local lines = vim.split(result, "\n", { plain = true })
                if lines[#lines] == "" then table.remove(lines) end
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

                vim.notify("✓ Translated (" .. target .. ")", vim.log.levels.INFO)
            end)
        end)
    end)
end

function M.replace(from_visual)
    local text = get_text(from_visual)
    if not text or text == "" then
        return vim.notify("No text to translate", vim.log.levels.WARN)
    end
    local target = get_target_lang()
    if not target then return end

    local buf = vim.api.nvim_get_current_buf()
    local ft = vim.bo.filetype
    vim.notify("⏳ Translating...", vim.log.levels.INFO)

    ensure_server(function()
        translate(text, target, ft, function(result)
            vim.schedule(function()
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
    end)
end

return M
