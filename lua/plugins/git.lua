local M = {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    opts = {
        signs = {
            add = { text = "▎" },
            change = { text = "▎" },
            delete = { text = "" },
            topdelete = { text = "" },
            changedelete = { text = "▎" },
            untracked = { text = "▎" },
        },
        signs_staged = {
            add = { text = "▎" },
            change = { text = "▎" },
            delete = { text = "" },
            topdelete = { text = "" },
            changedelete = { text = "▎" },
        },
        on_attach = function(buffer)
            local gs = package.loaded.gitsigns

            local function map(mode, l, r, desc)
                vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
            end

            -- stylua: ignore start
            map("n", "]h", function()
                if vim.wo.diff then
                    vim.cmd.normal({ "]c", bang = true })
                else
                    gs.nav_hunk("next")
                end
            end, "Next Hunk")
            map("n", "[h", function()
                if vim.wo.diff then
                    vim.cmd.normal({ "[c", bang = true })
                else
                    gs.nav_hunk("prev")
                end
            end, "Prev Hunk")
            map("n", "]H", function() gs.nav_hunk("last") end, "Last Hunk")
            map("n", "[H", function() gs.nav_hunk("first") end, "First Hunk")
            map({ "n", "v" }, "<leader>gS", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
            map({ "n", "v" }, "<leader>gR", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
            map("n", "<leader>gs", gs.stage_buffer, "Stage Buffer")
            map("n", "<leader>gu", gs.undo_stage_hunk, "Undo Stage Hunk")
            map("n", "<leader>gr", gs.reset_buffer, "Reset Buffer")
            map("n", "<leader>gp", gs.preview_hunk_inline, "Preview Hunk Inline")
            map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame Line")
            map("n", "<leader>gB", function() gs.blame() end, "Blame Buffer")
            map("n", "<leader>gd", function()
                vim.g._gitsigns_diff_mode = true
                gs.diffthis()
            end, "Diff This")
            map("n", "<leader>gD", function()
                vim.g._gitsigns_diff_mode = true
                gs.diffthis("~")
            end, "Diff This ~")
            map('n', '<leader>gq', gs.setqflist)
            map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
            -- Conflict resolution （在 3-way diff 模式中生效）
            -- 扫描所有冲突块，返回起止行列表 {{s, e}, ...}
            local function conflict_blocks(lines)
                local blocks, s = {}, 0
                for i = 1, #lines do
                    local l = lines[i]
                    if l:match("^<<<<<<<") then
                        s = i
                    elseif s > 0 and l:match("^>>>>>>>") then
                        blocks[#blocks + 1] = { s, i }
                        s = 0
                    end
                end
                return blocks
            end

            -- 包含光标的块；光标在块间时返回下一个块
            local function conflict_block_range()
                local cur = vim.fn.line(".")
                local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
                for _, b in ipairs(conflict_blocks(lines)) do
                    if b[2] >= cur then
                        return b[1], b[2]
                    end
                end
                vim.notify("Not in a conflict block", vim.log.levels.WARN)
            end

            local function accept_block(side)
                local s, e = conflict_block_range()
                if s then vim.cmd(string.format("%d,%ddiffget :%d", s, e, side)) end
            end
            map("n", "<leader>go", function() accept_block(2) end, "Accept whole block (:2 ours)")
            map("n", "<leader>gt", function() accept_block(3) end, "Accept whole block (:3 theirs)")

            -- 追加 unmerged 文件的冲突块条目（gitsigns 'all' 会过滤 UU 文件）
            local function qf_append_conflicts()
                local out = vim.system({ "git", "diff", "--name-only", "--diff-filter=U" }):wait()
                local items = {}
                for _, f in ipairs(vim.split(out.stdout, "\n", { plain = true })) do
                    if f ~= "" then
                        local abs = vim.fn.fnamemodify(f, ":p")
                        local ok, lines = pcall(vim.fn.readfile, abs)
                        if ok then
                            local blocks = conflict_blocks(lines)
                            for _, b in ipairs(blocks) do
                                items[#items + 1] = { filename = abs, lnum = b[1], text = "conflict block" }
                            end
                            if #blocks == 0 then
                                items[#items + 1] = { filename = abs, lnum = 1, text = "unmerged (no conflict markers)" }
                            end
                        end
                    end
                end
                if #items > 0 then
                    vim.fn.setqflist({}, "a", { items = items })
                end
            end
            map('n', '<leader>gQ', function()
                gs.setqflist('all', { open = false }, function()
                    qf_append_conflicts()
                    vim.cmd.copen()
                end)
            end)

            -- 切文件时跟随 diff 视图：条件 = 前一个 buffer 处于 3-way/2-way（diff 浏览模式）
            -- 状态 _gitsigns_diff_mode：gd 置 true，跟随成功保持，无任何 diff 迹象时重置
            local augroup = vim.api.nvim_create_augroup('gitsigns-conflict-qf', { clear = true })
            vim.api.nvim_create_autocmd('BufEnter', {
                group = augroup,
                callback = function()
                    if vim.g._gitsigns_rebuilding then
                        vim.g._gitsigns_pending = true -- 重建中又切文件：标记，完成后重触发
                        return
                    end
                    if not vim.g._gitsigns_diff_mode then
                        return
                    end
                    local cur = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
                    if cur == '' then
                        return
                    end
                    -- 扫描 diff 视图：revision 窗口 + 当前窗口 diff 状态
                    local has_rev, stale, root = false, {}, nil
                    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                        local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
                        local r, rel = name:match('^gitsigns://(.-)/%.git//:%d+:(.+)$')
                        if r and rel then
                            has_rev = true
                            root = root or r
                            if not (vim.startswith(cur, r) and cur:sub(#r + 2) == rel) then
                                stale[#stale + 1] = w
                            end
                        end
                    end
                    if not has_rev and not vim.wo.diff then
                        if not vim.g._gitsigns_rebuilding then
                            vim.g._gitsigns_diff_mode = false
                        end
                        return
                    end
                    -- 还在当前文件的 3-way/2-way 中（无其他文件的残留）：不动
                    if #stale == 0 then
                            return
                    end
                    -- 当前文件不在残留所属 repo 内则不处理（避免等 attach 卡顿）
                    if not (root and vim.startswith(cur, root)) then
                            return
                    end
                    -- 等 attach 完成：普通文件需 compare_text 就绪（diffthis 读它），冲突文件则等冲突检测
                    local bufnr = vim.api.nvim_get_current_buf()
                    if not vim.wait(2000, function()
                        local bc = require('gitsigns.cache').cache[bufnr]
                        return bc and bc.git_obj and (bc.compare_text ~= nil or bc.git_obj.has_conflicts)
                    end) then
                            return
                    end
                    -- 关闭旧 revision 窗口（触发 BufHidden，原窗口 diff 自动清除）
                    for _, w in ipairs(stale) do
                        vim.api.nvim_win_close(w, true)
                    end
                    -- 统一 diffthis：冲突文件自动 3-way，普通文件 2-way（vs index）
                    vim.g._gitsigns_rebuilding = true
                    require('gitsigns.async').run(function()
                        local ok, err = pcall(gs.diffthis)
                        if not ok then
                            vim.notify(err, vim.log.levels.ERROR)
                        end
                        -- 等 diffthis 的窗口落地（diffthis 会让出到事件循环，wait 驱动它恢复）
                        vim.wait(1000, function()
                            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                                if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match('gitsigns://') then
                                    return true
                                end
                            end
                            return false
                        end)
                        vim.g._gitsigns_rebuilding = nil
                        -- 重建期间又切了文件：重触发 BufEnter 处理最新的当前文件
                        if vim.g._gitsigns_pending then
                            vim.g._gitsigns_pending = nil
                            vim.api.nvim_exec_autocmds('BufEnter', {})
                        end
                    end)
                end,
            })
        end,
    },
}

return M
