local M = {
    'esmuellert/codediff.nvim',
    cmd = 'CodeDiff',
    -- VSCode 风格 diff/merge/history 查看器，替代 gitsigns 的 diffthis + qflist + 冲突解决
    opts = {
        -- 行级只设置低饱和背景，保留 Treesitter 的多色前景；
        -- 具体改动字符使用主题的 DiffText，以高对比度突出差异。
        highlights = {
            line_insert = '#62693e', -- gruvbox.nvim dark_green
            line_delete = '#722529', -- gruvbox.nvim dark_red
            char_insert = 'DiffText',
            char_delete = 'DiffText',
        },
        diff = {
            layout = 'side-by-side',
            original_position = 'left',   -- 旧版本(left) 在左、工作版本(right) 在右，符合 diffthis 习惯
        },
        keymaps = {
            view = {
                next_hunk = ']h',
                prev_hunk = '[h',
            },
            conflict = {
                accept_current  = '<leader>go',  -- 接受 ours（原 :2，保留肌肉记忆）
                accept_incoming = '<leader>gt',  -- 接受 theirs（原 :3）
            },
        },
    },
    keys = {
        { '<leader>gd', '<Cmd>CodeDiff file HEAD<CR>',   desc = 'Diff: file vs HEAD' },
        { '<leader>gD', '<Cmd>CodeDiff file HEAD~1<CR>', desc = 'Diff: file vs HEAD~1' },
        { '<leader>ge', '<Cmd>CodeDiff<CR>',             desc = 'Diff: changed files' },
        { '<leader>gh', '<Cmd>CodeDiff history<CR>',     desc = 'Diff: commit history' },
    },
}

return M
