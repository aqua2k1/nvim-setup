-- 翻译管线: 按行分块 + 串行翻译 + 失败重试(递增退避)
-- 依赖 transport 的调度约定: 所有回调已在主循环上下文
local M = {}
local config = require("user-plugins.translate.config")
local transport = require("user-plugins.translate.transport")

-- 行内切点(超长单行用)优先级: 句末标点 → 分句标点 → max 硬切
local SENTENCE_MARKS = { "。", "！", "？", "!", "?" }
local CLAUSE_MARKS = { "；", ";", "，", ",", "、" }

-- 在 [1, max] 前缀内找最佳切点(字节位置, 片段 = line:sub(1, cut))
-- 句末标点优先于分句标点(即使更远); 每级取最后一个 ≤ max 的匹配
-- "." 仅当后随空白时算句末(避开 3.14 / v1.2.3 / URL)
-- 兜底: max 处直接切(可能切断多字节字符, 已知取舍)
local function find_cut_point(line, max)
    local function last_before(marks, dot_rule)
        local last = nil
        for _, mark in ipairs(marks) do
            local pos = 1
            while true do
                local s = line:find(mark, pos, true)
                if not s or s > max then break end
                if not dot_rule or line:sub(s + 1, s + 1):find("%s") then
                    last = s
                end
                pos = s + 1
            end
        end
        return last
    end
    return last_before(SENTENCE_MARKS)
        or last_before({ "." }, true)
        or last_before(CLAUSE_MARKS)
        or max
end

-- 按行将原文切成若干块, 每块不超过 max_chunk_chars 字符
-- 行是格式的最小单元: 空行是普通行, 原样保留; 块内/块间均用 "\n" 拼接, 不增删空行
-- 超长单行: 优先在句末/分句标点处切; 片段仍属同一行(continues=true), 组装时以 "" 拼接
-- 不变量: M.join(chunks, chunks) == 原文
function M.split_into_chunks(text)
    local max = config.max_chunk_chars
    if #text <= max then
        return { { text = text, continues = false } }
    end
    local chunks, cur, cur_len, cur_continues = {}, {}, 0, false
    local function flush()
        if #cur > 0 then
            chunks[#chunks + 1] = { text = table.concat(cur, "\n"), continues = cur_continues }
            cur, cur_len, cur_continues = {}, 0, false
        end
    end
    for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
        if #line > max then
            -- 超长单行: 先清空当前块, 再按切点切分
            flush()
            local is_first_fragment = true
            while #line > max do
                local cut = find_cut_point(line, max)
                chunks[#chunks + 1] = {
                    text = line:sub(1, cut),
                    continues = not is_first_fragment,
                }
                line = line:sub(cut + 1)
                is_first_fragment = false
            end
            if line ~= "" then
                cur[1], cur_len = line, #line
                cur_continues = true  -- 剩余片段续上一块
            end
        else
            if #cur > 0 and cur_len + 1 + #line > max then
                flush()
            end
            cur[#cur + 1] = line
            cur_len = cur_len + #line + (#cur == 1 and 0 or 1)
        end
    end
    flush()
    return chunks
end

-- 按块缝拼接译文: parts[i] 与 chunks[i] 一一对应(parts 是已成功译文的前缀)
-- 续行块(continues=true)与上一块间不插换行, 其余用 "\n"
function M.join(parts, chunks)
    local out = {}
    for i, p in ipairs(parts) do
        if i > 1 and not chunks[i].continues then
            out[#out + 1] = "\n"
        end
        out[#out + 1] = p
    end
    return table.concat(out)
end

-- 串行翻译多个块: 上一块完成才发下一块(服务器 -np 1, 并行只会排队)
-- 单块失败自动重试 max_retries 次(2s/4s/6s... 递增退避), 耗尽才停止整链, 保留已译部分
-- chunks: split_into_chunks 返回的结构体({ text, continues })列表
-- opts.on_chunk(result, idx, total): 每块译文到达后调用, 返回 false 提前终止(如侧栏被关闭, 不重试)
-- opts.on_done(parts): 终止时调用(全部完成/重试耗尽/取消), parts = 已成功译文列表
-- 通知: 进度/重试/最终失败在此发出; 成功摘要由调用方在 on_done 里发出
function M.run(chunks, target, ft, opts)
    local i, parts = 1, {}
    local function next_chunk()
        if i > #chunks then
            return opts.on_done(parts)
        end
        local retries = 0
        local function attempt()
            if retries == 0 then
                if #chunks == 1 then
                    vim.notify("⏳ Translating...", vim.log.levels.INFO)
                else
                    vim.notify(string.format("⏳ Translating chunk %d/%d...", i, #chunks), vim.log.levels.INFO)
                end
            else
                vim.notify(string.format("⏳ Retrying chunk %d/%d (%d/%d)...", i, #chunks, retries, config.max_retries), vim.log.levels.INFO)
            end
            transport.translate(chunks[i].text, target, ft, function(result, err)
                if not result then
                    if retries < config.max_retries then
                        retries = retries + 1
                        vim.defer_fn(attempt, 2 * retries)  -- 退避 2s/4s/6s...
                    else
                        local detail = err and string.format(" (%s)", err) or ""
                        vim.notify(string.format("✗ Translation failed at chunk %d/%d%s", i, #chunks, detail), vim.log.levels.ERROR)
                        return opts.on_done(parts)
                    end
                    return
                end
                parts[#parts + 1] = result
                if opts.on_chunk and opts.on_chunk(result, i, #chunks) == false then
                    return opts.on_done(parts)
                end
                i = i + 1
                next_chunk()
            end)
        end
        attempt()
    end
    next_chunk()
end

return M
