return {
    cmd = {
        'lua-language-server',
        '--locale=zh-cn',
    },
    settings = {
        Lua = {
            diagnostics = {
                unusedLocalExclude = { '_*' },
                globals = { 'vim' },
                disable = {
                    'luadoc-miss-see-name',
                    'undefined-field',
                },
            },
            runtime = { version = 'LuaJIT' },
            workspace = {
                library = {
                    vim.env.VIMRUNTIME .. '/lua',
                    '${3rd}/busted/library',
                    '${3rd}/luv/library',
                },
                checkThirdParty = false,
            },
            completion = { callSnippet = 'Replace' },
        },
    },
}
