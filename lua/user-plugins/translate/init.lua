-- 自定义翻译插件
-- 依赖: llama.cpp + llama-server + Hy-MT2 翻译模型
-- 操作:
--   <leader>at  翻译选中/全文到侧栏 scratch buffer
--   <leader>aT  翻译选中/全文并替换当前 buffer
-- 结构:
--   config     配置(host/port/模型/分块/重试)
--   transport  curl HTTP 层(唯一处理 vim.schedule 调度的地方)
--   server     llama-server 生命周期(ensure/start/poll)
--   pipeline   分块 + 串行翻译 + 重试管线
-- 长文本按行分块(≤ max_chunk_chars 字符/块)串行翻译, 逐块追加到侧栏

local M = {}

local server = require("user-plugins.translate.server")
local pipeline = require("user-plugins.translate.pipeline")

-- ====== 用户交互 ======

local function get_target_lang()
    local target = vim.fn.input("Translate to (en/zh): ", "zh")
    if target == "" then return nil end
    target = target:lower()
    if target ~= "en" and target ~= "zh" then
        vim.notify("Invalid language. Use en or zh.", vim.log.levels.WARN)
        return nil
    end
    return target
end

-- 获取选区文本: 返回 { text, s, e, type }, 整篇时 s/e/type 为 nil
-- 可视模式进行中: 'v 标记(选区起点) + 光标位置('.') 实时可用, 无需退出可视模式
--   ('< '> 标记只在退出可视模式后才提交, 可视进行中读不到)
-- 非可视模式调用: 回退到上次选区 ('< '>)
local function get_text(from_visual)
    local mode = vim.api.nvim_get_mode().mode
    local s, e, t
    if from_visual and (mode == "v" or mode == "V" or mode == "\22") then
        s, e, t = vim.fn.getpos("v"), vim.fn.getpos("."), mode
    elseif from_visual then
        s = vim.fn.getpos("'<")
        if s[2] == 0 then return nil end
        e, t = vim.fn.getpos("'>"), vim.fn.visualmode()
    else
        return {
            text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"),
        }
    end
    return {
        s = s, e = e, type = t,
        text = table.concat(vim.fn.getregion(s, e, { type = t }), "\n"),
    }
end

-- ====== 公共编排 ======

-- 选区/全文 → 语言 → 分块 → 确保服务器 → 跑管线
-- ctx = { sel, target, ft, buf, chunks }: 在异步前捕获的选择时上下文
-- handlers.setup(ctx): 启动服务器前调用(如先开侧栏窗口)
-- handlers.on_chunk / on_done: 透传给 pipeline.run, on_done 额外带 ctx
local function translate_selection(from_visual, handlers)
    local sel = get_text(from_visual)
    if not sel or sel.text == "" then
        return vim.notify("No text to translate", vim.log.levels.WARN)
    end
    local target = get_target_lang()
    if not target then return end

    local ctx = {
        sel = sel,
        target = target,
        ft = vim.bo.filetype,
        buf = vim.api.nvim_get_current_buf(),
        chunks = pipeline.split_into_chunks(sel.text),
    }
    if handlers.setup then handlers.setup(ctx) end
    server.ensure(function()
        pipeline.run(ctx.chunks, ctx.target, ctx.ft, {
            on_chunk = handlers.on_chunk
                and function(result, i, total) return handlers.on_chunk(result, i, total, ctx) end,
            on_done = function(parts) handlers.on_done(parts, ctx) end,
        })
    end)
end

-- ====== 操作 ======

function M.split(from_visual)
    local buf
    translate_selection(from_visual, {
        setup = function(ctx)
            -- 先建好侧栏 buffer, 各块译文到达后逐块追加(块间仅换行, 保持原文行结构)
            vim.cmd("vsplit")
            vim.cmd("enew")
            buf = vim.api.nvim_get_current_buf()
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].filetype = ctx.ft
            vim.api.nvim_buf_set_name(buf, "Translation")
        end,
        on_chunk = function(result, i, _total, ctx)
            if not vim.api.nvim_buf_is_valid(buf) then
                vim.notify("Translation buffer closed, stopped", vim.log.levels.WARN)
                return false  -- 终止后续块
            end
            local lines = vim.split(result, "\n", { plain = true })
            if lines[#lines] == "" then table.remove(lines) end
            if #lines == 0 then return true end
            if ctx.chunks[i].continues then
                -- 续行块(超长行切片段): 首行并入侧栏末行末尾, 其余正常追加
                local lc = vim.api.nvim_buf_line_count(buf)
                local last = vim.api.nvim_buf_get_lines(buf, lc - 1, lc, false)[1]
                vim.api.nvim_buf_set_lines(buf, lc - 1, lc, false, { last .. lines[1] })
                vim.api.nvim_buf_set_lines(buf, -1, -1, false, vim.list_slice(lines, 2, #lines))
            elseif vim.api.nvim_buf_line_count(buf) == 1
                and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "" then
                -- 新 buffer 自带一个空行: 整体替换, 避免顶部空行
                vim.api.nvim_buf_set_lines(buf, 0, 1, false, lines)
            else
                vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
            end
            return true
        end,
        on_done = function(parts, ctx)
            if #parts > 0 then
                local msg = #ctx.chunks == 1
                    and "✓ Translated (" .. ctx.target .. ")"
                    or string.format("✓ Translated %d/%d chunks (%s)", #parts, #ctx.chunks, ctx.target)
                vim.notify(msg, vim.log.levels.INFO)
            end
        end,
    })
end

function M.replace(from_visual)
    translate_selection(from_visual, {
        on_done = function(parts, ctx)
            if #parts == 0 then return end  -- 失败原因已由 pipeline 通知
            local buf, sel = ctx.buf, ctx.sel
            local lines = vim.split(pipeline.join(parts, ctx.chunks), "\n", { plain = true })
            if lines[#lines] == "" then table.remove(lines) end

            if sel.s then
                local s, e = sel.s, sel.e
                if sel.type == "v" then
                    -- 字符选中: 只替换选中范围, 保留行内其他内容
                    -- ('v 的 col 1-based 含起点, 光标 '.' 指向选中末字符, set_text 的 end_col 排他)
                    if s[2] > e[2] or (s[2] == e[2] and s[3] > e[3]) then s, e = e, s end
                    vim.api.nvim_buf_set_text(buf, s[2] - 1, s[3] - 1, e[2] - 1, e[3], lines)
                else
                    local sr, er = s[2], e[2]
                    if sr > er then sr, er = er, sr end
                    vim.api.nvim_buf_set_lines(buf, sr - 1, er, false, lines)
                end
            else
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            end
            vim.bo[buf].modified = true

            vim.notify("✓ Translated " .. #lines .. " lines (" .. ctx.target .. ")", vim.log.levels.INFO)
        end,
    })
end

return M
