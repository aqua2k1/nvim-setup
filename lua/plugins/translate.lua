return {
    dir = vim.fn.stdpath("config") .. "/lua/user-plugins/translate",
    name = "translate",
    lazy = true,
    keys = {
        { "<leader>at", function() require("user-plugins.translate").split(false) end, mode = "n", desc = "翻译全文到侧栏" },
        { "<leader>at", function() require("user-plugins.translate").split(true) end,  mode = "x", desc = "翻译选中到侧栏" },
        { "<leader>aT", function() require("user-plugins.translate").replace(false) end, mode = "n", desc = "替换全文翻译" },
        { "<leader>aT", function() require("user-plugins.translate").replace(true) end,  mode = "x", desc = "替换选中翻译" },
    },
}
