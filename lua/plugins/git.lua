local M = {
    'esmuellert/codediff.nvim',
    cmd = 'CodeDiff',
    -- VSCode 风格 diff/merge/history 查看器，替代 gitsigns 的 diffthis + qflist + 冲突解决
    opts = {
        diff = {
            layout = 'side-by-side',
            original_position = 'left',   -- 旧版本(left) 在左、工作版本(right) 在右，符合 diffthis 习惯
        },
        keymaps = {
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
