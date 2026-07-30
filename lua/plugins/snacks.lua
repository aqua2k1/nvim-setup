local M = {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
        animate = { enabled = false },
        dashboard = { enabled = false },
        debug = { enabled = false },
        dim = { enabled = false },
        explorer = { enabled = false },
        gh = { enabled = false },
        git = { enabled = false },
        gitbrowse = { enabled = false },
        indent = { enabled = false },
        input = { enabled = false },
        keymap = { enabled = false },
        layout = { enabled = false },
        lazygit = { enabled = false },
        notifier = { enabled = false },
        notify = { enabled = false },
        picker = { enabled = false },
        rename = { enabled = false },
        scope = { enabled = false },
        scratch = { enabled = false },
        terminal = { enabled = false },
        toogle = { enabled = false },
        win = { enabled = false },
        zen = { enabled = false },
        bufdelte = { enabled = false },

        bigfile = { enabled = true },
        quickfile = { enabled = true },
        image = { enabled = true },
        scroll = { enabled = true },
        statuscolumn = { enabled = true },
        words = { enabled = true },
        styles = {
            notification = {
                -- wo = { wrap = true } -- Wrap notifications
            }
        }
    },
    keys = {
        -- Other
        { "]]", function() Snacks.words.jump(vim.v.count1) end,  desc = "Next Reference", mode = { "n", "t" } },
        { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference", mode = { "n", "t" } },
    },
    init = function()
        vim.api.nvim_create_autocmd("User", {
            pattern = "VeryLazy",
            callback = function()
                -- Setup some globals for debugging (lazy-loaded)
                _G.dd = function(...)
                    Snacks.debug.inspect(...)
                end
                _G.bt = function()
                    Snacks.debug.backtrace()
                end

                -- Override print to use snacks for `:=` command
                if vim.fn.has("nvim-0.11") == 1 then
                    vim._print = function(_, ...)
                        dd(...)
                    end
                else
                    vim.print = _G.dd
                end
            end,
        })
    end,
}

return M
