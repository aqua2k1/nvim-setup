-- llama-server 生命周期: 确保服务器就绪(未运行时启动, 轮询 /health 最多 30 次)
local M = {}
local config = require("user-plugins.translate.config")
local transport = require("user-plugins.translate.transport")

local function poll_until_ready(cb, attempts)
    attempts = (attempts or 0) + 1
    if attempts > 30 then
        vim.notify("llama-server failed to start", vim.log.levels.ERROR)
        return
    end

    transport.get_health(function(ok)
        if ok then
            cb()
        else
            vim.defer_fn(function() poll_until_ready(cb, attempts) end, 300)
        end
    end)
end

local function start_server(cb)
    local bin = vim.fn.exepath("llama-server")
    if bin == "" then
        vim.notify(
            "llama-server not found in $PATH\nInstall via package manager, or build and add to PATH (see scripts/llama-translate.sh)",
            vim.log.levels.ERROR
        )
        return
    end

    vim.system({
        bin,
        "-m", config.model,
        "-ngl", "99",
        "-c", tostring(config.context),
        "-np", "1",
        "--port", tostring(config.port),
        "--host", config.host,
        "--sleep-idle-seconds", tostring(config.idle_seconds),
    }, { detach = true })

    vim.notify("llama-server starting...", vim.log.levels.INFO)
    poll_until_ready(cb)
end

-- 确保服务器就绪: 健康则立即回调, 否则启动并轮询; 回调在主循环上下文
function M.ensure(cb)
    transport.get_health(function(ok)
        if ok then
            return cb()
        end
        start_server(cb)
    end)
end

return M
