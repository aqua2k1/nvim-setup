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
                providers = {
                    pi_agent = {
                        module = 'user-plugins.pi-agent-completion',
                        name = 'pi_agent',
                        min_keyword_length = 0, -- @ / 后 0 字符也要触发
                        -- 与内置 path source 同时命中时 (触发字符含 / 和 .),
                        -- 让 skill/@ 结果排最前, path 结果排后面
                        score_offset = 100,
                    },
                },
                default = { 'snippets', 'lsp', 'path', 'buffer', 'pi_agent' },
            },
        },
    },
}

return M
