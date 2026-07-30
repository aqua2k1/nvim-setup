#!/usr/bin/env bash
# 编译 llama.cpp (CUDA) + 下载 Hy-MT2 1.8B 模型
# 用法: ./scripts/llama-translate.sh
set -euo pipefail

LLAMA_DIR="$HOME/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build"
MODEL="tencent/Hy-MT2-1.8B-GGUF:Q4_K_M"

echo "=== Cloning/updating llama.cpp ==="
if [ -d "$LLAMA_DIR" ]; then
    cd "$LLAMA_DIR" && git pull --ff-only
else
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
    cd "$LLAMA_DIR"
fi

echo "=== Building with CUDA ==="
cmake -B "$BUILD_DIR" -DGGML_CUDA=ON
cmake --build "$BUILD_DIR" --config Release -j"$(nproc)"

echo "=== Downloading model ==="
"$BUILD_DIR/bin/llama-cli" -hf "$MODEL" --version

echo ""
echo "=== Done ==="
echo "Model cached at: $(dirname "$("$BUILD_DIR/bin/llama-cli" -hf "$MODEL" --print-model-path 2>/dev/null || echo ~/.cache/llama.cpp)")"
echo ""
echo "Start server:  $BUILD_DIR/bin/llama-server -hf $MODEL -ngl 99 --port 8080 --host 127.0.0.1"
