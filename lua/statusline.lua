local colors = require("utils.colors")

for group, settings in pairs({
    Statusline                = { bg = colors.bg6 },
    StatuslineNC              = { fg = colors.fg6, bg = colors.bg6, reverse = false },
    StatuslineItalic          = { fg = colors.grey, italic = true },
    StatuslineTitle           = { fg = colors.white, bold = true },
    StatuslineFile            = { fg = colors.white, bold = true },
    StatuslineModified        = { fg = colors.red, bold = true },
    StatuslineGit             = { fg = colors.blue, bold = true },
    StatuslineMode            = { fg = colors.white, bold = true },
    StatuslineModeNormal      = { fg = colors.white, bold = true },
    StatuslineModeInsert      = { fg = colors.green, bold = true },
    StatuslineModeVisual      = { fg = colors.blue, bold = true },
    StatuslineModeReplace     = { fg = colors.red, bold = true },
    StatuslineModeCommand     = { fg = colors.orange, bold = true },
    StatuslineModeTerminal    = { fg = colors.cyan, bold = true },
    StatuslineModeOpPending   = { fg = colors.yellow, bold = true },
    StatuslineModeSelect      = { fg = colors.magenta, bold = true },
    StatuslineEncoding        = { fg = colors.green, bold = true },
    StatuslinePosition        = { fg = colors.white, bold = true },
}) do
    vim.api.nvim_set_hl(0, group, settings)
end

local M = {}

-- 模式已在状态栏显示，关闭命令行里的 -- INSERT -- 避免重复
vim.o.showmode = false

--- vim 模式指示，Emacs 风格置于最左: NORMAL / INSERT / VISUAL / ...
---@return string
function M.mode_component()
    local spec = ({
        n = { 'NORMAL', 'Normal' },
        no = { 'OP-PENDING', 'OpPending' },
        nov = { 'OP-PENDING', 'OpPending' },
        noV = { 'OP-PENDING', 'OpPending' },
        ['no\22'] = { 'OP-PENDING', 'OpPending' },
        v = { 'VISUAL', 'Visual' },
        V = { 'V-LINE', 'Visual' },
        ['\22'] = { 'V-BLOCK', 'Visual' },
        s = { 'SELECT', 'Select' },
        S = { 'S-LINE', 'Select' },
        ['\19'] = { 'S-BLOCK', 'Select' },
        i = { 'INSERT', 'Insert' },
        R = { 'REPLACE', 'Replace' },
        Rv = { 'V-REPLACE', 'Replace' },
        c = { 'COMMAND', 'Command' },
        cv = { 'EX', 'Command' },
        ce = { 'EX', 'Command' },
        r = { 'PROMPT', 'Command' },
        rm = { 'MORE', 'Command' },
        t = { 'TERMINAL', 'Terminal' },
    })[vim.fn.mode(1)] or { 'NORMAL', 'Normal' }
    return string.format('%%#StatuslineMode%s#%s', spec[2], spec[1])
end

--- 编码+换行助记符（Emacs mule-info, %z%Z 风格）, 最左区: U: / U\ / U/
---@return string
function M.encoding_component()
    local enc = vim.opt.fileencoding:get()
    if enc == '' then
        return ''
    end
    local mnemonic = ({
        ['utf-8'] = 'U',
        ['utf-16le'] = 'u',
        ['latin1'] = '1',
    })[enc] or enc:upper()
    local eol = ({
        unix = ':',
        dos = '\\',
        mac = '/',
    })[vim.opt.fileformat:get()] or ':'
    return '%#StatuslineEncoding#' .. mnemonic .. eol
end

--- 修改/只读标记（vim 原生 %m %r）+ 文件路径。
--- 窗口窄（<100 列）时只显示文件名，否则显示 ~ 完整路径。
---@return string
function M.file_component()
    local marks = '%#StatuslineModified#%m%r'
    if vim.fn.winwidth(0) < 100 then
        return marks .. '%#StatuslineFile# %t'
    end
    local path = vim.fn.fnamemodify(vim.fn.expand('%:p'), ':~')
    if path == '' then
        path = '[No Name]'
    end
    if vim.bo.buftype == 'help' then
        path = '[Help] ' .. path
    end
    return marks .. '%#StatuslineFile# ' .. path
end

-- Git branch via `git branch --show-current` (异步，不依赖 gitsigns)。
-- 缓存到模块级变量，BufEnter/DirChanged 时刷新，仅在变更时重绘 statusline。
local git_head = ""
local refreshing = false
local function refresh_git_head()
    if refreshing then
        return
    end
    refreshing = true
    vim.system({ "git", "branch", "--show-current" }, { text = true }, function(out)
        refreshing = false
        local head = out.code == 0 and vim.trim(out.stdout or "") or ""
        if head ~= git_head then
            git_head = head
            vim.schedule(function()
                vim.cmd.redrawstatus()
            end)
        end
    end)
end

vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
    group = vim.api.nvim_create_augroup("mingzi47/statusline-git", { clear = true }),
    desc = "Refresh git branch for statusline",
    callback = refresh_git_head,
})
refresh_git_head() -- initial

--- Vc-mode like git indicator: Git-main
---@return string
function M.git_component()
    if git_head == "" then
        return ""
    end
    return "%#StatuslineGit# Git-" .. git_head
end

--- 位置: 百分比 + (行,零基列)  如 60% (25,10)
---@return string
function M.position_component()
    local win = vim.fn.getwininfo(vim.fn.win_getid())[1]
    local total = math.max(vim.fn.line('$'), 1)
    local pct = math.floor((win.topline - 1) * 100 / total)
    return '%#StatuslinePosition#'
        .. string.format('%d%%%%', pct)
        .. " (%l,%{col('.')-1})"
end

--- 模式（Emacs mode-line-modes）: [(Lua)]
---@return string
function M.mode_component_menlo()
    local ft = vim.bo.filetype
    if ft == '' then
        ft = 'Fundamental'
    else
        ft = ft:gsub('^%w', string.upper)
    end
    local inner = '%#StatuslineMode#(' .. ft .. ')'
    return '%#StatuslineMode#[' .. inner .. ']'
end

--- Renders the statusline: 单行连续流（Emacs modeline），无左右分栏。
---@return string
function M.render()
    ---@param components string[]
    ---@return string
    local function concat_components(components)
        return vim.iter(components):skip(1):fold(components[1], function(acc, component)
            return #component > 0 and string.format('%s  %s', acc, component) or acc
        end)
    end

    return concat_components {
        M.mode_component(),
        M.encoding_component(),
        M.file_component(),
        M.position_component(),
        M.git_component(),
        M.mode_component_menlo(),
    } .. ' '
end

vim.o.statusline = "%!v:lua.require'statusline'.render()"

return M
