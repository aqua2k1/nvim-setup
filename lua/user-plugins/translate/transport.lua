-- 传输层: llama-server 的 HTTP 接口(curl)
-- 调度约定: 所有回调都在主循环上下文触发。
--   vim.system 的 on_exit 可能落在 fast event context, 必须 vim.schedule 切回主循环,
--   这是全插件唯一需要关心调度的地方, 下游模块无需再包 schedule。
local M = {}
local config = require("user-plugins.translate.config")

local function curl(extra_args, cb)
    local argv = { "curl", "-s" }
    for _, a in ipairs(extra_args) do
        argv[#argv + 1] = a
    end
    vim.system(argv, { text = true }, function(r)
        vim.schedule(function() cb(r) end)
    end)
end

-- GET /health → cb(ok)
function M.get_health(cb)
    curl({ config.health_url }, function(r)
        cb(r.code == 0 and r.stdout and r.stdout:find('"ok"'))
    end)
end

-- POST /v1/chat/completions → cb(content, err)
-- content: 译文, 失败为 nil; err: 失败原因描述(供最终通知), 成功为 nil
function M.translate(text, target, ft, cb)
    local lang = target == "zh" and "Chinese" or "English"
    local hint = ft ~= "" and string.format(" (%s source)", ft) or ""
    local prompt = string.format(
        "Translate the following%s to %s. Preserve code, markup, and formatting exactly, including line breaks and blank lines.\n\n%s",
        hint, lang, text
    )

    curl({
        "--max-time", "120",
        "-X", "POST", config.api_url,
        "-H", "Content-Type: application/json",
        "-d", vim.json.encode({
            model = "hy-mt2",
            messages = { { role = "user", content = prompt } },
            temperature = 0.1,
            max_tokens = 8192,
        }),
    }, function(r)
        if r.code ~= 0 then
            return cb(nil, "curl failed: " .. (r.stderr or "unknown"))
        end
        local ok, decoded = pcall(vim.json.decode, r.stdout)
        if not ok or not decoded.choices or not decoded.choices[1] then
            return cb(nil, "unexpected response")
        end
        cb(decoded.choices[1].message.content)
    end)
end

return M
