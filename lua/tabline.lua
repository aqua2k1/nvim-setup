local colors = require("utils.colors")

for group, settings in pairs({
    TabLine = { fg = colors.fg7, bg = colors.bg7 },
    TabLineSel = { fg = colors.white, bg = colors.bg2, bold = true },
    TabLineFill = { fg = colors.fg7, bg = colors.bg7 },
    TabLineHint = { fg = colors.black, bg = colors.green },
}) do
    vim.api.nvim_set_hl(0, group, settings)
end


local M = {}

function M.render()
    local s = ''
    for i = 1, vim.fn.tabpagenr('$') do
        if i == vim.fn.tabpagenr() then
            s = s .. '%#TabLineSel#'
        else
            s = s .. '%#TabLine#'
        end
        s = s .. '%' .. i .. 'T' -- 鼠标点击事件

        local winnr = vim.fn.tabpagewinnr(i)
        local buflist = vim.fn.tabpagebuflist(i)
        local bufnr = buflist[winnr]
        local bufname = vim.fn.bufname(bufnr)
        local filename = vim.fn.fnamemodify(bufname, ':t') -- 只取文件名

        if filename == "" then
            filename = "[No Name]"
        end

        s = s .. ' ' .. i .. ': ' .. filename .. '  '
    end

    s = s .. '%#TabLineFill#%T' -- 填充剩余空间

    return s
end

vim.o.tabline = "%!v:lua.require'tabline'.render()"

-- keymap
-- [number] gt desc = "switch tab"
local map = vim.keymap.set
map("n", "<C-w>t", [[<cmd>tab sbuffer<cr>]], { desc = "Open Current buffer into new Tab" })

return M
