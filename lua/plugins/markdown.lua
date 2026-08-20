local M = {
    'OXY2DEV/markview.nvim',
    lazy = false,                          -- markview 官方要求不要 lazy-load
    dependencies = {
        'nvim-treesitter/nvim-treesitter',
        'nvim-mini/mini.icons',
    },
    opts = {
        preview = { icon_provider = 'mini' },   -- 复用 mini.icons（原 render-markdown 也用）
        -- hybrid_mode 默认开启 = 原 render_modes = {'i','n','c','t'}（边编辑边预览）
    },
    config = function(_, opts)
        require('mini.icons').setup()
        require('markview').setup(opts)
    end,
}

return M
