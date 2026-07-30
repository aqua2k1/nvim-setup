-- P1: disable mini.pairs backtick pairing in markdown (buffer-local override).
-- T1/M1+M3/N2/X1: only show fence snippet when the line is exactly ``` (no leading whitespace).

vim.keymap.set('i', '`', function()
  vim.schedule(function()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local before = vim.api.nvim_get_current_line():sub(1, col)
    if before ~= '```' then
      return
    end

    local ok, cmp = pcall(require, 'blink.cmp')
    if ok then
      cmp.show({ providers = { 'snippets' } })
    end
  end)
  return '`'
end, { buffer = true, expr = true, desc = 'Markdown code fence trigger' })
