local function augroup(name)
  return vim.api.nvim_create_augroup("mingzi_nvim_" .. name, { clear = true })
end

-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
    group = augroup("checktime"),
    callback = function()
        if vim.o.buftype ~= "nofile" then
        vim.cmd("checktime")
        end
    end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
    group = augroup("highlight_yank"),
    callback = function()
        (vim.hl or vim.highlight).on_yank()
    end,
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
    group = augroup("resize_splits"),
    callback = function()
        local current_tab = vim.fn.tabpagenr()
        vim.cmd("tabdo wincmd =")
        vim.cmd("tabnext " .. current_tab)
    end,
})

-- go to last loc when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup("last_loc"),
    callback = function(event)
        local exclude = { "gitcommit" }
        local buf = event.buf
        if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
        return
        end
        vim.b[buf].lazyvim_last_loc = true
        local mark = vim.api.nvim_buf_get_mark(buf, '"')
        local lcount = vim.api.nvim_buf_line_count(buf)
        if mark[1] > 0 and mark[1] <= lcount then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
    group = augroup("close_with_q"),
    pattern = {
        "PlenaryTestPopup",
        "checkhealth",
        "dbout",
        "gitsigns-blame",
        "grug-far",
        "help",
        "lspinfo",
        "neotest-output",
        "neotest-output-panel",
        "neotest-summary",
        "notify",
        "qf",
        "spectre_panel",
        "startuptime",
        "tsplayground",
    },
    callback = function(event)
        vim.bo[event.buf].buflisted = false
        vim.schedule(function()
        vim.keymap.set("n", "q", function()
            vim.cmd("close")
            pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
        end, {
            buffer = event.buf,
            silent = true,
            desc = "Quit buffer",
        })
        end)
    end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = augroup("auto_create_dir"),
    callback = function(event)
        if event.match:match("^%w%w+:[\\/][\\/]") then
        return
        end
        local file = vim.uv.fs_realpath(event.match) or event.match
        vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end,
})

-- automatically enter insert mode on opening terminal
vim.api.nvim_create_autocmd("TermOpen", {
    group = augroup("terminal"),
    pattern = "*",
    callback = function()
        vim.cmd("startinsert")
    end,
})

local uname = vim.loop.os_uname()
local is_mac = uname.sysname == "Darwin"
if is_mac then
    local ImeAutoGroup = augroup("ImeAutoGroup")

    vim.api.nvim_create_autocmd("InsertLeave", {
        group = ImeAutoGroup,
        callback = function ()
            vim.system({ "macism" }, { text = true }, function(out)
                -- 用一个全局变量存储之前的语言
                PREVIOUS_IM_CODE_MAC = string.gsub(out.stdout, "\n", "")
            end)
            vim.cmd ":silent :!macism com.apple.keylayout.ABC"
        end
    })


    vim.api.nvim_create_autocmd("InsertEnter", {
        group = ImeAutoGroup,
        callback = function ()
            if vim.bo.buftype ~= "" then
                return
            end
            if PREVIOUS_IM_CODE_MAC then
                vim.cmd(":silent :!macism " .. PREVIOUS_IM_CODE_MAC)
            end
            PREVIOUS_IM_CODE_MAC = ""
        end
    })
end
