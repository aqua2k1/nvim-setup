-- pi 输入补全: @ 路径补全
-- fd (已装 /usr/sbin/fd) 列目录内容 + 本地前缀过滤, 天然尊重 .gitignore
-- 目录优先 (两次调用合并), 目录可继续连补, 文件尾补空格 (对齐 pi 内置习惯)

local M = {}

local FD_LIMIT = 30
local kinds = require("blink.cmp.types").CompletionItemKind

local function make_item(display, insert, is_dir)
    return {
        label = display,
        kind = is_dir and kinds.Folder or kinds.File,
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        insertText = insert,
        detail = display,
    }
end

--- fd 异步列 base 下 dir 层的条目, 输出相对路径列表
--- 参数: fd --base-directory base [--full-path --fixed-strings --ignore-case]
---       --max-depth <段数+1> --max-results 30 --type d|f <dir..name>
--- 子串匹配 + 深度限制 = 恰好列出目标层的直接子项 (fd 对含 / 的 pattern
--- 默认只匹配 basename, 必须 --full-path; glob 模式在 fd 10.4 不可靠, 用子串)
--- @param base string  搜索根 (cwd / HOME / /)
--- @param dir string   相对 base 的子目录 (含尾 /, 可为 "")
--- @param name string  前缀过滤 (可为 "")
--- @param type_flag string "d" | "f"
--- @param callback fun(paths: string[])
local function list_fd(base, dir, name, type_flag, callback)
    if vim.fn.executable("fd") ~= 1 then
        callback({})
        return
    end
    local depth = 0
    for _ in dir:gmatch("([^/]+)/") do
        depth = depth + 1
    end
    local args = {
        "fd", "--base-directory", base, "--color", "never",
        "--max-results", tostring(FD_LIMIT), "--max-depth", tostring(depth + 1),
        "--hidden", -- ~ 下 .agents 等隐藏目录也要可补
        "--type", type_flag,
    }
    if dir == "" and name == "" then
        -- 顶层: 无 pattern 列全部
    else
        table.insert(args, "--full-path")
        table.insert(args, "--fixed-strings")
        table.insert(args, "--ignore-case")
        table.insert(args, dir .. name)
    end
    return vim.system(args, { text = true }, function(obj)
        if obj.code ~= 0 then
            callback({})
            return
        end
        local paths = {}
        for line in (obj.stdout or ""):gmatch("[^\r\n]+") do
            table.insert(paths, line)
        end
        callback(paths)
    end)
end

-- 并发去重: 击键快于 fd 返回时, 只采纳最新一轮
local gen = 0

--- @param query string "@" 之后的光标前文本 (可为 "")
--- @param on_items fun(response: blink.cmp.CompletionResponse)
--- @return fun()|nil 取消函数: kill 未完成的 fd 进程
function M.suggest(query, on_items)
    local my_gen = gen + 1
    gen = my_gen

    local handles = {} -- vim.system 返回的 SystemObj, 供取消时 kill

    -- 解析基准目录与显示前缀
    local base, prefix = vim.fn.getcwd(), ""
    local q = query
    if q:match("^~/?") then
        base, prefix = vim.fn.expand("~"), "~/"
        q = q:gsub("^~/?", "")
    elseif q:sub(1, 1) == "/" then
        base, prefix = "/", "/"
    elseif base:match("/tmp/pi%-editor%-") then
        -- 异常: cwd 被拽到 pi 临时目录 (exrc 等干扰), 兜底用 HOME
        base, prefix = vim.fn.expand("~"), "~/"
    end

    -- 拆分目录部分与名称前缀
    local dir, name = q:match("^(.-/)([^/]*)$")
    if not dir then
        dir, name = "", q
    end

    local function finish(dirs, files)
        if gen ~= my_gen then return end -- 已有更新的查询
        local items = {}
        for _, d in ipairs(dirs) do
            local clean = d:gsub("/$", "") -- fd 输出目录自带尾 /, 去掉统一由 make_item 加
            table.insert(items, make_item(prefix .. clean .. "/", "@" .. prefix .. clean .. "/", true))
        end
        for _, f in ipairs(files) do
            table.insert(items, make_item(prefix .. f, "@" .. prefix .. f .. " ", false))
        end
        on_items({ items = items }) -- blink 期待响应结构 { items = ... }
    end

    local h1 = list_fd(base, dir, name, "d", function(dirs)
        local h2 = list_fd(base, dir, name, "f", function(files)
            finish(dirs, files)
        end)
        if h2 then table.insert(handles, h2) end
    end)
    if h1 then table.insert(handles, h1) end

    -- kill 后 on_exit 仍会回调, 但 gen 检查会丢弃旧结果
    return function()
        for _, h in ipairs(handles) do
            pcall(function() h:kill() end)
        end
    end
end

return M
