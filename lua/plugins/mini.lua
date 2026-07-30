local surround = {
    'echasnovski/mini.surround',
    version = '*',
    opts = {
        mappings = {
            add = 'sa',            -- Acommentdd surrounding in Normal and Visual modes
            delete = 'sd',         -- Delete surrounding
            find = 'sf',           -- Find surrounding (to the right)
            find_left = 'sF',      -- Find surrounding (to the left)
            highlight = 'sh',      -- Highlight surrounding
            replace = 'sr',        -- Replace surrounding
            update_n_lines = 'sn', -- Update `n_lines`

            suffix_last = 'l',     -- Suffix to search with "prev" method
            suffix_next = 'n',     -- Suffix to search with "next" method
        },
    },
    keys = {
        { "sa", "sa", mode = { "n", "v", "o" }, desc = "Add srround" },
        { "sd", "sd", mode = { "n", "v", "o" }, desc = "Delete surround" },
        { "sr", "sr", mode = { "n", "v", "o" }, desc = "Replace surround" },
        { "sf", "sf", mode = { "n", "v", "o" }, desc = "Find surround (to the right)" },
        { "sF", "sF", mode = { "n", "v", "o" }, desc = "Find surround (to the Left)" },
        { "sn", "sn", mode = { "n", "v", "o" }, desc = "Update 'n_lines'" },
    }
}

local autopairs = {
    "echasnovski/mini.pairs",
    event = { "InsertEnter" },
    opts = {
        modes = { insert = true, command = true, terminal = false },
        -- skip autopair when next character is one of these
        skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
        -- skip autopair when the cursor is inside these treesitter nodes
        skip_ts = { "string" },
        -- skip autopair when next character is closing pair
        -- and there are more closing pairs than opening pairs
        skip_unbalanced = true,
        -- better deal with markdown code blocks
        markdown = true,
    }
}

return {
    surround,
    autopairs,
}
