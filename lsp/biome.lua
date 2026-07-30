vim.lsp.config('biome', {
    root_dir = function(bufnr, on_dir)
        local root = vim.fs.root(bufnr, { 'package.json', '.git' })
        on_dir(root or vim.fn.getcwd())
    end,
})

return {}
