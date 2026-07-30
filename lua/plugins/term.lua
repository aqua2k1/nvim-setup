local map = vim.keymap.set
local unmap = vim.keymap.del

local M = {
    'akinsho/toggleterm.nvim',
    lazy    = true,
    version = "*",
    opts    = {
        size = function(term)
            local ui = vim.api.nvim_list_uis()[1]
            if term.direction == "horizontal" then
                return ui.height / 2
            elseif term.direction == "vertical" then
                return ui.width / 2
            end
        end,
        on_open = function(term)
            local opts = { buffer = term.bufnr }
            vim.api.nvim_buf_set_name(term.bufnr, "Terminal")

            map('t', '<esc><esc>', [[<C-\><C-n>]], opts)
            map('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
            map('t', '<C-w>h', [[<Cmd>wincmd h<CR>]], opts)
            map('t', '<C-w>j', [[<Cmd>wincmd j<CR>]], opts)
            map('t', '<C-w>k', [[<Cmd>wincmd k<CR>]], opts)
            map('t', '<C-w>l', [[<Cmd>wincmd l<CR>]], opts)
            map('t', '<C-j>', [[<down>]], opts)
            map('t', '<C-k>', [[<up>]], opts)
            map('n', 'q', [[<cmd>close<cr>]], opts)
            map('n', 'q', function()
                vim.cmd('TermExec cmd=""')
                vim.cmd('TermExec cmd="exit"')
            end, opts)
        end,
        on_close = function()
            vim.print("yes")
        end,
        float_opts = {
            border = "double",
            title_pos = "center",
        },
    }
}

local function toggle(opts)
    require('toggleterm.terminal').
        Terminal:new(opts):toggle()
end

function M.float_term()
    return {
        direction = "float",
    }
end

function M.split_term()
    return {
        direction = "horizontal",
    }
end

function M.vsplit_term()
    return {
        direction = "vertical",
    }
end

function M.tab_term()
    return {
        direction = "tab",
    }
end

function M.input_command()
    local function format_data(data)
        local cleaned = {}
        for _, line in ipairs(data) do
            local cleaned_line = line:gsub('\x1b%[[%d;]*[A-Za-z]', '')
            cleaned_line = cleaned_line:gsub("\r", "")
            table.insert(cleaned, cleaned_line)
        end

        return cleaned
    end

    -- TODO
    -- local buf_ft = vim.api.nvim_get_option_value('filetype', { buf = 0 })
    local opts = {
        close_on_exit = false,
        on_open = function()
            -- clear qf
            vim.fn.setqflist({}, 'r')
        end,
        on_stdout = function(_, _, data)
            data = format_data(data)
            vim.fn.setqflist({}, "a", { lines = data })
        end,
        on_stderr = function(_, _, data)
            data = format_data(data)
            vim.fn.setqflist({}, "a", { lines = data })
        end
    }

    vim.ui.input({ prompt = 'Enter Command: ' }, function(input)
        opts.cmd = input
    end)

    return opts
end

M.keys = {
    { "<leader>tv", function() toggle(M.vsplit_term()) end,   desc = "vsplit" },
    { "<leader>ts", function() toggle(M.split_term()) end,    desc = "split" },
    { "<leader>tf", function() toggle(M.float_term()) end,    desc = "float" },
    { "<leader>tt", function() toggle(M.tab_term()) end,      desc = "tab" },
    { "<leader>tc", function() toggle(M.input_command()) end, desc = "Input Command" },
}


return M
