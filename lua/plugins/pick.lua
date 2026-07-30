local M = {
    "ibhagwan/fzf-lua",
    keys = {
        -- 文件查找
        { "<leader>ff", function() require('fzf-lua').files({ prompt = 'Find file> ', cwd_prompt = false }) end, desc = "Find Files (Root)" },
        { "<leader>fF", function() require('fzf-lua').files({ prompt = 'Find file> ', cwd_prompt = false, cwd = vim.fn.input('Directory: ', vim.fn.getcwd()) }) end, desc = "Find Files (CWD)" },
        { "<leader>fg", function() require('fzf-lua').git_files({ prompt = 'Git files> ', cwd_prompt = false }) end, desc = "Find Git Files" },
        { "<leader>fo", function() require('fzf-lua').oldfiles({ prompt = 'Recent> ', cwd_prompt = false }) end, desc = "Recent Files" },
        -- 内容搜索
        { "<leader>fw", function() require('fzf-lua').live_grep({ prompt = 'Grep> ', input_prompt = 'Grep> ', cwd_prompt = false }) end, desc = "Grep (Root)" },
        { "<leader>fW", function() require('fzf-lua').live_grep({ prompt = 'Grep> ', input_prompt = 'Grep> ', cwd_prompt = false, cwd = vim.fn.input('Directory: ', vim.fn.getcwd()) }) end, desc = "Grep (CWD)" },
        -- Buffers
        { "<leader>,",  function() require('fzf-lua').buffers({ prompt = 'Buffer> ', cwd_prompt = false }) end, desc = "Switch Buffer" },
        { "<leader>bb", function() require('fzf-lua').buffers({ prompt = 'Buffer> ', cwd_prompt = false }) end, desc = "Buffers" },
        -- LSP
        { "<leader>fd", function() require('fzf-lua').lsp_definitions({ prompt = 'Definitions> ' }) end,         desc = "Definitions" },
        { "<leader>fr", function() require('fzf-lua').lsp_references({ prompt = 'References> ' }) end,          desc = "References" },
        { "<leader>fa", function() require('fzf-lua').lsp_code_actions({ prompt = 'Code Actions> ' }) end,      desc = "Code Actions" },
        { "<leader>fs", function() require('fzf-lua').lsp_document_symbols({ prompt = 'Symbols> ' }) end,       desc = "Document Symbols" },
        { "<leader>fS", function() require('fzf-lua').lsp_workspace_symbols({ prompt = 'Workspace> ' }) end,    desc = "Workspace Symbols" },

        -- 其他
        { "<leader>fh", function() require('fzf-lua').helptags({ prompt = 'Help> ' }) end,                      desc = "Help" },
        { "<leader>fk", function() require('fzf-lua').keymaps({ prompt = 'Keymaps> ' }) end,                    desc = "Keymaps" },
        { "<leader>fc", function() require('fzf-lua').commands({ prompt = 'Commands> ' }) end,                  desc = "Commands" },
    },
    opts = {
        'ivy',
        winopts = {
            border = 'none',
            treesitter = {
                enabled = false,
            },
            preview = {
                hidden = true,
            },
        },
        keymap = {
            builtin = {
                ["<C-j>"] = "down",           -- 向下
                ["<C-k>"] = "up",             -- 向上
                ["<C-p>"] = "toggle-preview", -- 预览切换
                ["<C-/>"] = "toggle-help",    -- 帮助切换
                ["<C-v>"] = "ctrl-v",         -- 垂直分割
                ["<C-s>"] = "ctrl-x",         -- 水平分割（用 ctrl-s）
                ["<C-t>"] = "ctrl-t",         -- 新标签
            },
        },
    },
}

return M
