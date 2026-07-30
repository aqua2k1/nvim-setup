local M = {
    'nvim-treesitter/nvim-treesitter',
    branch = "main",
    cmd = { "TSInstall", "TSUpdate", "TSUninstall" },
    config = function()
        require("nvim-treesitter.install").command_extra_args = {
            curl = { "--insecure" },
        }
        local install = require('nvim-treesitter.install')
        local config_mod = require('nvim-treesitter.config')

        -- Core parsers: 预装最常用的，其余按需自动安装
        local core_parsers = {
            "lua", "vim", "vimdoc", "markdown", "markdown_inline",
            "bash", "c", "go", "python", "rust", "cpp", "json", "yaml",
            "toml", "html", "diff", "query",
        }
        vim.schedule(function()
            install.install(core_parsers, { summary = true })
        end)

        -- 自动安装未安装的 parser
        local available = config_mod.get_available()
        vim.api.nvim_create_autocmd('FileType', {
            group = vim.api.nvim_create_augroup('nvim-treesitter-install', { clear = true }),
            callback = function(args)
                local lang = vim.treesitter.language.get_lang(args.match)
                if not lang then return end

                local installed = config_mod.get_installed()
                if not vim.tbl_contains(installed, lang)
                    and vim.tbl_contains(available, lang) then
                    install.install({ lang })
                end
            end,
        })

        -- 原生 treesitter 折叠 + 缩进
        vim.api.nvim_create_autocmd('FileType', {
            group = vim.api.nvim_create_augroup('nvim-treesitter-native', { clear = true }),
            callback = function(args)
                local lang = vim.treesitter.language.get_lang(args.match)
                if not lang then return end

                if vim.treesitter.query.get(lang, 'indents') then
                    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end
            end,
        })
    end,
}

return M
