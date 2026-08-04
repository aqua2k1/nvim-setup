-- blink.cmp source: pi 输入补全
-- 仅对 pi 外部编辑器打开的 buffer (/tmp/pi-editor-*/prompt.md) 生效:
--   "@"  -> 相对路径补全 (paths)
--   "/"  -> skill 补全 (skills)
-- 其他 buffer 一律返回空, 不干扰日常补全

local source = {}

function source.new(opts)
    return setmetatable({}, { __index = source })
end

-- @ 和 / 都不是 blink 的 keyword 字符, 声明为 trigger 才能"按下立即弹出":
-- 输入 @ -> 顶层路径, 输入 / -> 全部 skill
function source.get_trigger_characters()
    return { '@', '/' }
end

function source:get_completions(ctx, on_items)
    local bufnr = ctx and ctx.bufnr or vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    if not buf_name:match("pi%-editor%-.+prompt%.md$") then
        on_items({ items = {} })
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0) -- {row(1-based), col(0-based)}
    local line = vim.api.nvim_buf_get_lines(bufnr, cursor[1] - 1, cursor[1], false)[1] or ""
    local before = line:sub(1, cursor[2])

    -- "@" 路径补全: @ 前须为行首或空白/左括号 (Lua pattern 无 lookbehind/非捕获组, 手动校验前字符)
    local at = before:match("@([^%s@]*)$")
    if at ~= nil then
        local at_pos = #before - #at - 1 -- @ 的 0-based 字节位置
        if at_pos <= 0 or before:sub(at_pos, at_pos):match("[%s(]") then
            -- 返回取消函数 (kill 未完成的 fd 进程)
            return require("user-plugins.pi-agent-completion.paths").suggest(at, on_items)
        end
    end

    -- "/" skill 补全: / 前须为行首或空白 (命令位置), / 后无空格无嵌套 /
    -- (Lua pattern 无 lookbehind, 手动校验 / 前字符; 放宽行首限制是为了
    -- 支持 "@src/main.ts /tdd" 这类 @ 补全后继续输入命令的场景)
    local slash = before:match("/[^%s/]*$")
    if slash ~= nil then
        local slash_pos = #before - #slash -- / 的 0-based 字节位置
        if slash_pos == 0 or before:sub(slash_pos, slash_pos):match("%s") then
            require("user-plugins.pi-agent-completion.skills").suggest(
                vim.fn.getcwd(), slash:sub(2), on_items)
            return
        end
    end

    on_items({ items = {} })
end

return source
