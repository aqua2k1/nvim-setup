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
    StatuslineLSPClients      = { fg = colors.white, bold = true },
    StatuslineDiagnosticError = { fg = colors.red, bold = true },
    StatuslineDiagnosticWarn  = { fg = colors.yellow, bold = true },
    StatuslineDiagnosticHint  = { fg = colors.dblue, bold = true },
    StatuslineDiagnosticInfo  = { fg = colors.cyan, bold = true },
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

---@type table<string, string?>
local progress_status = {
    client = nil,
    kind = nil,
    title = nil,
}

vim.api.nvim_create_autocmd('LspProgress', {
    group = vim.api.nvim_create_augroup('mingzi47/statusline', { clear = true }),
    desc = 'Update LSP progress in statusline',
    pattern = { 'begin', 'end' },
    callback = function(args)
        -- This should in theory never happen, but I've seen weird errors.
        if not args.data then
            return
        end

        progress_status = {
            client = vim.lsp.get_client_by_id(args.data.client_id).name,
            kind = args.data.params.value.kind,
            title = args.data.params.value.title,
        }

        if progress_status.kind == 'end' then
            progress_status.title = nil
            -- Wait a bit before clearing the status.
            vim.defer_fn(function()
                vim.cmd.redrawstatus()
            end, 3000)
        else
            vim.cmd.redrawstatus()
        end
    end,
})

--- The current buffer attach clients: (clangd, lua_ls)
---@return string
function M.lsp_clients()
    local clients = vim.lsp.get_clients()
    local current_buf = vim.api.nvim_get_current_buf()

    local active_clients = vim.tbl_filter(function(client)
        return client and client.attached_buffers and client.attached_buffers[current_buf]
    end, clients)

    local client_names = vim.tbl_map(function(client)
        return client.name or "unknown"
    end, active_clients)

    if #active_clients == 0 then
        return ""
    end

    return "%#StatuslineLSPClients#(" .. table.concat(client_names, ", ") .. ")"
end

--- The latest LSP progress message, 纯文字: clangd: Building...
---@return string
function M.lsp_progress_component()
    if not progress_status.client or not progress_status.title then
        return M.lsp_clients()
    end

    return table.concat {
        string.format('%%#StatuslineTitle#%s:', progress_status.client),
        string.format(' %%#StatuslineItalic#%s...', progress_status.title),
    }
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

local last_diagnostic_component = ''
--- 诊断计数（flycheck 文字，作 minor-mode 放模式括号内）: E3 W1
---@return string
function M.diagnostics_component()
    -- Use the last computed value if in insert mode.
    if vim.startswith(vim.api.nvim_get_mode().mode, 'i') then
        return last_diagnostic_component
    end

    local counts = vim.iter(vim.diagnostic.get(0)):fold({
        ERROR = 0,
        WARN = 0,
        HINT = 0,
        INFO = 0,
    }, function(acc, diagnostic)
        local severity = vim.diagnostic.severity[diagnostic.severity]
        acc[severity] = acc[severity] + 1
        return acc
    end)

    local parts = {}
    local letters = { ERROR = "E", WARN = "W", HINT = "H", INFO = "I" }
    for severity, count in pairs(counts) do
        if count > 0 then
            local name = severity:sub(1, 1) .. severity:sub(2):lower()
            table.insert(parts, string.format('%%#StatuslineDiagnostic%s#%s%d', name, letters[severity], count))
        end
    end

    -- 更新缓存并返回结果
    last_diagnostic_component = table.concat(parts, ' ')
    return last_diagnostic_component
end

--- 模式（Emacs mode-line-modes）: [(Lua E1 W2)]，诊断作 minor-mode 并入
---@return string
function M.mode_component_menlo()
    local ft = vim.bo.filetype
    if ft == '' then
        ft = 'Fundamental'
    else
        ft = ft:gsub('^%w', string.upper)
    end
    local inner = '%#StatuslineMode#(' .. ft .. ')'
    local diag = M.diagnostics_component()
    if diag ~= '' then
        inner = inner .. ' ' .. diag
    end
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
        M.lsp_progress_component(),
    } .. ' '
end

vim.o.statusline = "%!v:lua.require'statusline'.render()"

return M
