return {
    dir = vim.fn.stdpath("config") .. "/lua/user-plugins/ime",
    name = "ime",
    lazy = false,
    config = function()
        require("user-plugins.ime.autocmd")
    end,
}
