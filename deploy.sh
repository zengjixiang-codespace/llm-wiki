#!/usr/bin/env bash
# 一键发布：构建站点，把 public/ 强制推送到 gh-pages 分支。
# GitHub Pages 配置为「从 gh-pages 分支发布」，推送后约 1 分钟生效。
#
# 用法：./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

REMOTE="$(git remote get-url origin)"
echo "→ 构建站点"
node quartz/bootstrap-cli.mjs build

echo "→ 推送 gh-pages"
cd public
touch .nojekyll                      # 关掉 Jekyll，避免忽略下划线开头的文件
rm -rf .git
git init -q -b gh-pages
git add -A
git commit -qm "deploy: $(date '+%Y-%m-%d %H:%M:%S')"
git remote add origin "$REMOTE"
git -c credential.helper='!gh auth git-credential' push -f origin gh-pages

echo "✓ 已推送，稍等约 1 分钟生效：https://zengjixiang-codespace.github.io/llm-wiki/"
