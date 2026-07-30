local map = vim.keymap.set

-- Motion
map({ "n", "x" },       "j",  "v:count==0?'gj':'j'", { expr = true, silent = true, desc = "Down" })
map({ "n", "x" },       "k",  "v:count==0?'gk':'k'", { expr = true, silent = true, desc = "Up" })
map({ "n", "v", "o" },  "gh", "^",                   { silent = true, desc = "Line head" })
map({ "n", "v", "o" },  "gl", "$",                   { silent = true, desc = "Line tail" })
map({ "n", "o", "x", "v" }, "gm", "%",               { desc = "Match" })

-- Insert / command navigation
map({ "i", "c" }, "<C-h>", "<Left>",  { silent = true, desc = "Left" })
map({ "i", "c" }, "<C-l>", "<Right>", { silent = true, desc = "Right" })
map({ "i", "c" }, "<C-k>", "<Up>",    { silent = true, desc = "Up" })
map({ "i", "c" }, "<C-j>", "<Down>",  { silent = true, desc = "Down" })

-- Editor
map({ "i", "n", "s" }, "<Esc>", function()
    vim.cmd("noh")
    return "<Esc>"
end, { expr = true, desc = "Escape and clear hlsearch" })
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
map("n", "<C-c>", "<cmd>qa<cr>", { desc = "Quit" })
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Comments
map("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add comment below" })
map("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add comment above" })

-- Diagnostics
local function diag_jump(count, severity)
    return function()
        vim.diagnostic.jump({ count = count, severity = severity and vim.diagnostic.severity[severity] })
    end
end
map("n", "]d", diag_jump(1),           { desc = "Next diagnostic" })
map("n", "[d", diag_jump(-1),          { desc = "Prev diagnostic" })
map("n", "]e", diag_jump(1,  "ERROR"), { desc = "Next error" })
map("n", "[e", diag_jump(-1, "ERROR"), { desc = "Prev error" })
map("n", "]w", diag_jump(1,  "WARN"),  { desc = "Next warning" })
map("n", "[w", diag_jump(-1, "WARN"),  { desc = "Prev warning" })

-- Windows
map("n", "<C-Up>",    "<cmd>resize +2<cr>",          { desc = "Increase window height" })
map("n", "<C-Down>",  "<cmd>resize -2<cr>",          { desc = "Decrease window height" })
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Quickfix
local function qf_toggle()
    if vim.iter(vim.fn.getwininfo()):find(function(w) return w.quickfix == 1 end) then
        vim.cmd("cclose")
    elseif not vim.tbl_isempty(vim.fn.getqflist()) then
        vim.cmd("copen")
    end
end
map("n", "<leader>q", qf_toggle,     { desc = "Toggle quickfix" })
local function qf_prev()
    if vim.tbl_isempty(vim.fn.getqflist()) then return end
    if not pcall(vim.cmd.cprev) then vim.cmd.clast() end
end
local function qf_next()
    if vim.tbl_isempty(vim.fn.getqflist()) then return end
    if not pcall(vim.cmd.cnext) then vim.cmd.cfirst() end
end
map("n", "[q", qf_prev, { desc = "Prev quickfix" })
map("n", "]q", qf_next, { desc = "Next quickfix" })

-- Buffers
map("n", "<leader>bv", "<cmd>vsplit Empty<cr>", { desc = "Split vertical" })
map("n", "<leader>bs", "<cmd>split Empty<cr>",  { desc = "Split horizontal" })
map("n", "<leader>bc", "<cmd>enew<cr>",         { desc = "New buffer" })
map("n", "<leader>bd", "<cmd>bd!<cr>",          { desc = "Delete buffer" })
map("n", "[b",         "<cmd>bprevious<cr>",    { desc = "Prev buffer" })
map("n", "]b",         "<cmd>bnext<cr>",        { desc = "Next buffer" })

-- Misc
map("n", "<F10>", "<cmd>Lazy<cr>", { desc = "Lazy" })

-- Cmdline
-- 光标移动
map('c', '<C-b>', '<Left>')   -- 后退一个字符
map('c', '<C-f>', '<Right>')  -- 前进一个字符
map('c', '<C-a>', '<Home>')   -- 跳到行首
map('c', '<C-e>', '<End>')    -- 跳到行尾

-- 删除
map('c', '<C-d>', '<Del>')    -- 删除光标后一个字符
map('c', '<C-h>', '<BS>')     -- 删除光标前一个字符
map('c', '<C-w>', '<C-S-w>')  -- 删除前一个单词 (1)

-- 在历史命令中前后翻找
map('c', '<C-n>', '<Down>')   -- 下一条历史命令
map('c', '<C-p>', '<Up>')     -- 上一条历史命
