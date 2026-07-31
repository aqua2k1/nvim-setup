#!/usr/bin/env bash
# 查询 nvim 的 VIMRUNTIME 并写入 ~/.env（幂等，重复执行安全）
# 用法: ./scripts/set-vimruntime.sh
set -euo pipefail

ENV_FILE="$HOME/.env"

# nvim 启动时总会把自身的 runtime 路径放入子进程环境，这里取到的始终是真实值
VIMRUNTIME="$(nvim --headless +'lua io.stdout:write(vim.env.VIMRUNTIME); io.stdout:flush()' +qa 2>/dev/null)"

if [ -z "$VIMRUNTIME" ]; then
    echo "error: 无法获取 VIMRUNTIME（nvim 不可用？）" >&2
    exit 1
fi

ENTRY="export VIMRUNTIME=\"$VIMRUNTIME\""

# 严格幂等：恰好一行且值完全匹配（-x 全行、-F 字面量，无正则转义问题）才早退
if [ -f "$ENV_FILE" ] \
    && [ "$(grep -c '^export VIMRUNTIME=' "$ENV_FILE" || true)" -eq 1 ] \
    && grep -qxF "$ENTRY" "$ENV_FILE"; then
    echo "VIMRUNTIME 已是最新: $VIMRUNTIME"
    exit 0
fi

# 其余情况（多行脏数据 / 值不同 / 缺失）统一收敛：删全部旧行，追加正确行
sed -i '/^export VIMRUNTIME=/d' "$ENV_FILE"
printf '%s\n' "$ENTRY" >> "$ENV_FILE"
echo "VIMRUNTIME 已写入 $ENV_FILE: $VIMRUNTIME"
