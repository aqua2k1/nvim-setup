local icons = require("utils.icons")
local colors = require("utils.colors")

for group, settings in pairs({
    Statusline                = { bg = colors.bg6 },
    StatuslineNC              = { fg = colors.fg6, bg = colors.bg6, reverse = false },
    StatuslineItalic          = { fg = colors.grey, italic = true },
    StatuslineSpinner         = { fg = colors.white, bold = true },
    StatuslineTitle           = { fg = colors.white, bold = true },
    StatuslineFile            = { fg = colors.white, bold = true },
    StatuslineEncoding        = { fg = colors.green, bold = true },
    StatuslinePosition        = { fg = colors.white, bold = true },
    StatuslineGit             = { fg = colors.blue, bold = true },
    StatuslineLSPClients      = { fg = colors.white, bold = true },
    StatuslineDiagnosticError = { fg = colors.red },
    StatuslineDiagnosticWarn  = { fg = colors.yellow },
    StatuslineDiagnosticHint  = { fg = colors.dblue },
    StatuslineDiagnosticInfo  = { fg = colors.cyan },
}) do
    vim.api.nvim_set_hl(0, group, settings)
end

local M = {}

vim.o.showmode = true

-- Don't show the command that produced the quickfix list.
-- vim.g.qf_disable_statusline = 1
function M.get_file_path()
    local file_path = vim.fn.expand('%:p:h')

    local workspace = vim.fn.getcwd();

    local escaped_workspace = workspace:gsub("([^%w])", "%%%1")  -- 转义特殊字符
    local pattern = "^" .. escaped_workspace .. "/?"
    file_path = file_path:gsub(pattern, "")

    if file_path == "" then
        file_path = "."
    end

    return file_path
end

--- file info.
---@return string
function M.file_component()
    return string.format("%%#StatuslineFile# (%s) %%t %%h%%m%%r%%", M.get_file_path())
end

--- Git status (if any).
---@return string
function M.git_component()
    local head = vim.b.gitsigns_head
    if head == nil or head == '' then
        return '%#StatuslineGit#'
    end

    return string.format('%%#StatuslineGit# [Git:%s]', head)
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

        -- vim.print(args.data);
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

--- The current buffer attach clients.
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

--- The latest LSP progress message.
---@return string
function M.lsp_progress_component()
    if not progress_status.client or not progress_status.title then
        return M.lsp_clients()
    end

    return table.concat {
        '%#StatuslineSpinner#󱥸 ',
        string.format('%%#StatuslineTitle#%s  ', progress_status.client),
        string.format('%%#StatuslineItalic#%s...', progress_status.title),
    }
end

local last_diagnostic_component = ''
--- Diagnostic counts in the current buffer.
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
    for severity, count in pairs(counts) do
        if count > 0 then
            local name = severity:sub(1, 1) .. severity:sub(2):lower()
            local hl = 'StatuslineDiagnostic' .. name
            table.insert(parts, string.format('%%#%s#%s%d', hl, icons.diagnostics[name], count))
        end
    end

    -- 更新缓存并返回结果
    last_diagnostic_component = table.concat(parts, ' ')
    return last_diagnostic_component
end

--- File-content encoding for the current buffer.
---@return string
function M.encoding_component()
    local encoding = vim.opt.fileencoding:get()
    return encoding ~= '' and string.format('%%#StatuslineEncoding#[%s]', encoding) or ''
end

--- The current line, total line count, and column position.
---@return string
function M.position_component()
    return "%#StatuslinePosition#%P (%-2.(%l:%c%))"
end

--- Renders the statusline.
---@return string
function M.render()
    ---@param components string[]
    ---@return string
    local function concat_components(components)
        return vim.iter(components):skip(1):fold(components[1], function(acc, component)
            return #component > 0 and string.format('%s  %s', acc, component) or acc
        end)
    end

    return table.concat {
        -- left
        concat_components {
            M.file_component(),
            M.git_component(),
            M.diagnostics_component(),
        },

        -- mid
        concat_components {
            '%#StatusLine#%=',
            -- M.lsp_clients(),
            M.lsp_progress_component(),
            '%#StatusLine#%=',
        },

        -- right
        concat_components {
            M.encoding_component(),
            M.position_component(),
        },
        ' ',
    }
end

vim.o.statusline = "%!v:lua.require'statusline'.render()"

return M
