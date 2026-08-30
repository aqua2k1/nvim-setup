-- 配置与派生 URL
local M = {
    port = 9999,
    host = "127.0.0.1",
    max_chunk_chars = 1500,  -- 单次请求原文上限(字符); 超出按行分块, 逐块串行翻译
    max_retries = 3,  -- 单块翻译失败的最大重试次数(2s/4s/6s... 递增退避)
    min_side_width = 80,  -- vsplit 时单栏最小宽度(列); 低于则改用上下分屏
}

M.api_url = string.format("http://%s:%d/v1/chat/completions", M.host, M.port)
M.health_url = string.format("http://%s:%d/health", M.host, M.port)

return M
