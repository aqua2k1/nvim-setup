local M = {
    {
        'saghen/blink.cmp',
        event = { 'InsertEnter', 'CmdlineEnter' },
        version = '*',
        build = "cargo build --release",
        opts = {
            keymap = {
                preset = 'super-tab',
                ['<C-k>'] = { 'select_prev', 'fallback' },
                ['<C-j>'] = { 'select_next', 'fallback' },
            },
            completion = {
                trigger = {
                    show_in_snippet = true,
                },
                menu = {
                    auto_show = true,
                    border = 'rounded',
                },
                ghost_text = { enabled = true },
                documentation = {
                    auto_show = false,
                    window = {
                        border = 'rounded'
                    },
                },
            },
            signature = {
                enabled = true,
                window = {
                    border = 'rounded'
                },
            },
            cmdline = {
                completion = {
                    menu = {
                        auto_show = true
                    }
                },
                keymap = {
                    preset = 'inherit',
                },
            },
            sources = {
                default = { 'snippets', 'lsp', 'path', 'buffer' },
            },
        },
    },
}

return M
