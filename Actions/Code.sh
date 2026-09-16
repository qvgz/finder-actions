#!/bin/bash
# 使用 Code 打开当前文件夹
set -euo pipefail

target="${1:?缺少目标路径}"
if [[ ! -d "$target" ]]; then
    target="$(dirname -- "$target")"
fi

exec /usr/bin/open -a "Visual Studio Code" "$target"
