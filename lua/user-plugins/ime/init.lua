local M = {
    insert_leave = function() end,
    insert_enter = function() end,
}

local uname = vim.uv.os_uname()
local is_mac = uname.sysname == "Darwin"
local is_win = vim.fn.has("win32") == 1
    or vim.fn.has("wsl") == 1
    or (uname.release or ""):lower():find("microsoft", 1, true) ~= nil

if is_mac then
    local previous_mode

    M.insert_leave = function()
        vim.system({ "macism" }, { text = true }, function(result)
            previous_mode = vim.trim(result.stdout or "")
        end)
        vim.cmd ":silent :!macism com.apple.keylayout.ABC"
    end

    M.insert_enter = function()
        if vim.bo.buftype ~= "" then
            return
        end
        if previous_mode then
            vim.cmd(":silent :!macism " .. previous_mode)
        end
        previous_mode = nil
    end
elseif is_win then
    local ime = vim.fs.joinpath(
        vim.fn.stdpath("config"),
        "scripts",
        "ime",
        "ime.exe"
    )
    local job
    local ready = false
    local partial = ""
    local current
    local requests = {}
    local restore_pending = false
    local stopping = false
    local warning_shown = false

    local function warn_once(message)
        if not warning_shown then
            warning_shown = true
            vim.notify("Windows IME: " .. message, vim.log.levels.WARN)
        end
    end

    local flush
    local function handle_line(line)
        line = line:gsub("\r$", "")
        if line == "READY" then
            ready = true
            flush()
            return
        end
        if not current then
            return
        end

        local request = current
        current = nil
        vim.schedule(function()
            if line:sub(1, 6) == "ERROR " then
                warn_once(line:sub(7))
            elseif request.callback then
                request.callback(line)
            end
            flush()
        end)
    end

    local function on_stdout(_, data)
        for index, chunk in ipairs(data or {}) do
            partial = partial .. chunk
            if index < #data or chunk == "" then
                if partial ~= "" then
                    handle_line(partial)
                end
                partial = ""
            end
        end
    end

    local function start()
        if stopping or job then
            return job ~= nil
        end

        local id = vim.fn.jobstart({ ime, "--server" }, {
            on_stdout = on_stdout,
            stdout_buffered = false,
            on_exit = function()
                job = nil
                ready = false
                partial = ""
                if current then
                    table.insert(requests, 1, current)
                    current = nil
                end
                if not stopping and #requests > 0 then
                    warn_once("ime.exe stopped")
                    vim.schedule(function()
                        if start() then
                            flush()
                        end
                    end)
                end
            end,
        })

        if id <= 0 then
            job = nil
            return false
        end
        job = id
        return true
    end

    flush = function()
        if not ready or current or #requests == 0 then
            return
        end

        current = table.remove(requests, 1)
        local ok, sent = pcall(vim.fn.chansend, job, current.mode .. "\n")
        if not ok or sent <= 0 then
            table.insert(requests, 1, current)
            current = nil
            ready = false
            warn_once("failed to send a command to ime.exe")
        end
    end

    local function request(mode, callback)
        table.insert(requests, { mode = mode, callback = callback })
        if not start() then
            warn_once("ime.exe is unavailable; build scripts/ime/ime.exe")
            return
        end
        flush()
    end

    M.insert_leave = function()
        if vim.bo.buftype ~= "" then
            return
        end
        restore_pending = false
        request("en", function(output)
            previous_mode = output:match("^(en)")
                or output:match("^(zh)")
            if restore_pending and previous_mode then
                local mode = previous_mode
                previous_mode = nil
                restore_pending = false
                request(mode)
            end
        end)
    end

    M.insert_enter = function()
        if vim.bo.buftype ~= "" then
            return
        end
        if previous_mode then
            request(previous_mode)
            previous_mode = nil
        else
            restore_pending = true
        end
    end

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("mingzi_nvim_ime_server", {
            clear = true,
        }),
        callback = function()
            stopping = true
            if job then
                vim.fn.chanclose(job, "stdin")
            end
        end,
    })

    vim.schedule(start)
end

return M
