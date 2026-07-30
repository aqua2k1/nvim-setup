local M = {}

---配置并启用 LSP 服务器（如果未启用）
---@param server_name string 服务器名称
---@param config table LSP 服务器配置
function M.setup_lsp(server_name, config)
    if not vim.lsp.is_enabled(server_name) then
        vim.lsp.config(server_name, config)
        vim.lsp.enable(server_name)
    end
end

return M
