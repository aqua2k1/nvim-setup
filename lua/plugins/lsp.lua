local M = {
    'neovim/nvim-lspconfig',
    event = { 'VeryLazy' },
    config = function()
        -- Diagnostic display
        local icons = require('utils.icons')
        vim.diagnostic.config({
            underline = true,
            virtual_text = false,
            update_in_insert = false,
            severity_sort = true,
            signs = {
                text = {
                    icons.diagnostics.Error,
                    icons.diagnostics.Warn,
                    icons.diagnostics.Hint,
                    icons.diagnostics.Info,
                },
            },
        })

        -- Float diagnostic on cursor hold (copyable)
        vim.api.nvim_create_autocmd('CursorHold', {
            callback = function()
                vim.diagnostic.open_float({
                    border = 'rounded',
                    scope = 'cursor',
                })
            end,
        })

        -- Enable all LSP servers configured in user's lsp/ directory
        local servers = {}
        for _, file in ipairs(vim.fn.globpath(vim.fn.stdpath('config'), "lsp/*.lua", false, true)) do
            servers[#servers + 1] = vim.fn.fnamemodify(file, ":t:r")
        end
        vim.lsp.enable(servers)

        vim.api.nvim_create_autocmd('LspAttach', {
            callback = function(args)
                -- keymap: remove default K (keywordprg) before binding LSP hover
                pcall(vim.keymap.del, 'n', 'K', { buffer = args.buf })

                local opts = function(desc)
                    return {
                        desc = desc,
                        buffer = args.buf
                    }
                end

                local map = vim.keymap.set
                map('n', "gd", vim.lsp.buf.definition, opts("Go To Definition"))
                map('n', "K", function() vim.lsp.buf.hover({ border = "rounded" }) end,
                    opts("Hover Documentation"))
                map({ 'n', 'x' }, "grf", function() vim.lsp.buf.format({ async = true }) end,
                    opts("vim.lsp.buf.format()"))

                -- Auto-highlight symbol references on cursor hold
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if client and client:supports_method('textDocument/documentHighlight', args.buf) then
                    local hl_group = vim.api.nvim_create_augroup('lsp_document_highlight', { clear = false })
                    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                        buffer = args.buf,
                        group = hl_group,
                        callback = vim.lsp.buf.document_highlight,
                    })
                    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                        buffer = args.buf,
                        group = hl_group,
                        callback = vim.lsp.buf.clear_references,
                    })
                    vim.api.nvim_create_autocmd('LspDetach', {
                        group = vim.api.nvim_create_augroup('lsp_detach_cleanup', { clear = true }),
                        callback = function(e)
                            vim.lsp.buf.clear_references()
                            vim.api.nvim_clear_autocmds { group = 'lsp_document_highlight', buffer = e.buf }
                        end,
                    })
                end
            end
        })
    end
}

return M
