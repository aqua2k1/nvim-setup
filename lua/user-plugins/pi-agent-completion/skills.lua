-- pi 输入补全: / skill 补全
-- 扫描 pi 的 skill 目录, 解析 SKILL.md frontmatter, 子串匹配 skill 名
-- 插入 "/skill:<name> " (pi 的命令格式)

local M = {}

-- cwd 变化时自动重建, 无需显式刷新
local cache = { cwd = nil, skills = {} }

--- 解析 SKILL.md 前 20 行的 frontmatter (--- 块内的 name:/description:)
local function parse_frontmatter(lines)
    local name, description
    local in_fm, fm_closed = false, false
    for _, line in ipairs(lines) do
        if line == "---" then
            if not in_fm then
                in_fm = true
            else
                fm_closed = true
            end
        elseif in_fm and not fm_closed then
            local n = line:match("^name:%s*(.-)%s*$")
            local d = line:match("^description:%s*(.-)%s*$")
            if n then name = n end
            if d then description = d end
        elseif fm_closed then
            break
        end
    end
    return name, description
end

local function load_skills(cwd)
    local skills = {}
    local roots = {
        { dir = vim.fn.expand("~/.agents/skills"), scope = "user" },
        { dir = vim.fn.expand("~/.pi/agent/skills"), scope = "user" },
        { dir = cwd .. "/.agents/skills", scope = "project" },
        { dir = cwd .. "/.pi/skills", scope = "project" },
    }
    for _, root in ipairs(roots) do
        if vim.fn.isdirectory(root.dir) == 1 then
            for _, file in ipairs(vim.fs.find("SKILL.md", { path = root.dir, type = "file", limit = 200 })) do
                local name, description =
                    parse_frontmatter(vim.fn.readfile(file, "", 20))
                local dir_name = vim.fn.fnamemodify(vim.fn.fnamemodify(file, ":h"), ":t")
                table.insert(skills, {
                    name = name or dir_name, -- frontmatter 缺失时用目录名兜底
                    description = description,
                    scope = root.scope,
                })
            end
        end
    end
    return skills
end

--- @param cwd string
--- @param query string  "/" 之后的输入
--- @param on_items fun(response: blink.cmp.CompletionResponse)
function M.suggest(cwd, query, on_items)
    if cache.cwd ~= cwd then
        cache = { cwd = cwd, skills = load_skills(cwd) }
    end

    local q = query:lower()
    -- "/skill" 或 "/skill:tdd" 输入时剥离前缀: skill 名本身不含 "skill" 字样
    -- ("/skill" -> "" 显示全部, "/skill:tdd" -> "tdd")
    q = q:gsub("^skill:?", "")
    local kind = require("blink.cmp.types").CompletionItemKind.Text
    -- 注意: 不能用 Function/Method kind, blink 的 auto_brackets 会给这两类
    -- 自动追加 () (markdown 默认括号对), 导致插入后多出括号
    local items = {}
    for _, s in ipairs(cache.skills) do
        if s.name:lower():find(q, 1, true) then
            table.insert(items, {
                label = s.name,
                kind = kind,
                insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
                insertText = "/skill:" .. s.name .. " ",
                detail = (s.description or "") .. "  [" .. s.scope .. "]",
            })
        end
    end
    on_items({ items = items }) -- blink 期待响应结构 { items = ... }
end

return M
