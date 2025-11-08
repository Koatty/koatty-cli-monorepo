#!/bin/bash

# Koatty CLI Monorepo - 同步到独立仓库脚本
# 用法: ./scripts/sync-standalone.sh <package-name> [options]
#
# 选项:
#   --branch <branch>  指定目标分支（默认：自动检测当前分支）
#   --remote <url>     指定远程仓库 URL
#
# 环境变量:
#   GITHUB_TOKEN - GitHub Personal Access Token (用于 HTTPS 认证)
#   如果未设置，脚本会提示用户输入

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 包名映射（monorepo中的目录名 -> 独立仓库URL）
declare -A PACKAGE_REPOS=(
    ["koatty-cli"]="https://github.com/Koatty/koatty_cli.git"
    ["koatty-template"]="https://github.com/Koatty/koatty_template.git"
    ["koatty-template-cli"]="https://github.com/Koatty/koatty_template_cli.git"
    ["koatty-template-component"]="https://github.com/Koatty/koatty_template_component.git"
)

# 包的默认分支映射（当在 main/master 分支时使用）
declare -A PACKAGE_DEFAULT_BRANCHES=(
    ["koatty-cli"]="3.12.x"
    ["koatty-template"]="3.12.x"
    ["koatty-template-cli"]="3.12.x"
    ["koatty-template-component"]="master"
)

# 获取目标分支
# 逻辑：
# 1. 如果指定了 --branch 参数，使用指定的分支
# 2. 否则自动检测当前 Git 分支
# 3. 如果当前分支是 main/master，使用配置的默认分支
# 4. 否则使用当前分支名（支持多分支开发，如 4.x）
function get_target_branch() {
    local package_name=$1
    local specified_branch=$2
    
    # 如果指定了分支，直接使用
    if [ -n "$specified_branch" ]; then
        echo "$specified_branch"
        return 0
    fi
    
    # 检测当前分支
    local current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    
    if [ -z "$current_branch" ]; then
        echo -e "${YELLOW}⚠ 无法检测当前分支，使用默认分支${NC}" >&2
        echo "${PACKAGE_DEFAULT_BRANCHES[$package_name]:-master}"
        return 0
    fi
    
    # 如果当前分支是 main 或 master，使用配置的默认分支
    if [[ "$current_branch" == "main" ]] || [[ "$current_branch" == "master" ]]; then
        local default_branch="${PACKAGE_DEFAULT_BRANCHES[$package_name]:-master}"
        echo -e "${BLUE}ℹ 当前在 $current_branch 分支，使用默认目标分支: $default_branch${NC}" >&2
        echo "$default_branch"
        return 0
    fi
    
    # 否则使用当前分支名（支持多分支开发）
    echo -e "${BLUE}ℹ 检测到当前分支: $current_branch，将同步到同名分支${NC}" >&2
    echo "$current_branch"
}

# 清理函数 - 在退出时清理 remote 中的 token
function cleanup_on_exit() {
    if [ -n "$REMOTE_NAME" ] && [ -n "$REMOTE_URL" ] && [[ $REMOTE_URL =~ ^https:// ]]; then
        if git remote | grep -q "^${REMOTE_NAME}$"; then
            git remote set-url "$REMOTE_NAME" "$REMOTE_URL" 2>/dev/null || true
        fi
    fi
}

# 设置陷阱，确保退出时清理
trap cleanup_on_exit EXIT

# GitHub Token 处理函数
function get_github_token() {
    local token=""
    
    # 优先级 1: 环境变量
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN"
        return 0
    fi
    
    # 优先级 2: 项目根目录的 .github-token 文件
    local token_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.github-token"
    if [ -f "$token_file" ]; then
        token=$(cat "$token_file" | tr -d '[:space:]')
        if [ -n "$token" ]; then
            echo -e "${GREEN}✓${NC} 从 .github-token 文件读取 Token" >&2
            echo "$token"
            return 0
        fi
    fi
    
    # 优先级 3: 提示用户输入 Token
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${YELLOW}需要 GitHub Personal Access Token${NC}" >&2
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo -e "${BLUE}说明:${NC}" >&2
    echo "  同步到独立仓库需要 GitHub 认证" >&2
    echo "  您可以:" >&2
    echo "    1. 设置环境变量: export GITHUB_TOKEN=your_token" >&2
    echo "    2. 创建文件: echo 'your_token' > .github-token" >&2
    echo "    3. 现在手动输入 Token" >&2
    echo "" >&2
    echo -e "${BLUE}如何创建 Token:${NC}" >&2
    echo "  1. 访问: https://github.com/settings/tokens" >&2
    echo "  2. 点击 'Generate new token (classic)'" >&2
    echo "  3. 选择权限: repo (完整访问)" >&2
    echo "" >&2
    
    read -p "请输入 GitHub Token (输入将被隐藏): " -s token
    echo "" >&2
    
    if [ -z "$token" ]; then
        echo -e "${RED}错误: Token 不能为空${NC}" >&2
        exit 1
    fi
    
    echo "$token"
}

# 构建认证的 HTTPS URL
function build_authenticated_url() {
    local url=$1
    local token=$2
    
    # 检查是否是 HTTPS URL
    if [[ $url =~ ^https:// ]]; then
        # 将 https:// 替换为 https://x-access-token:TOKEN@
        echo "${url/https:\/\//https://x-access-token:${token}@}"
    else
        # SSH URL 或其他格式，直接返回
        echo "$url"
    fi
}

# 帮助信息
function show_help() {
    echo -e "${BLUE}用法:${NC}"
    echo "  ./scripts/sync-standalone.sh <package-name> [options]"
    echo ""
    echo -e "${BLUE}选项:${NC}"
    echo "  --branch <branch>   指定目标分支（默认：自动检测当前分支）"
    echo "  --remote <url>      指定远程仓库 URL"
    echo ""
    echo -e "${BLUE}分支策略:${NC}"
    echo "  1. 自动检测当前 monorepo 分支"
    echo "  2. 如果当前在 main/master，使用配置的默认分支"
    echo "  3. 否则同步到独立仓库的同名分支（支持多分支开发）"
    echo "  4. 使用 --branch 可覆盖自动检测"
    echo ""
    echo -e "${BLUE}环境变量:${NC}"
    echo "  GITHUB_TOKEN    GitHub Personal Access Token"
    echo "                  用于 HTTPS 认证，避免每次输入"
    echo ""
    echo -e "${BLUE}示例:${NC}"
    echo "  # 自动检测分支并同步"
    echo "  ./scripts/sync-standalone.sh koatty-cli"
    echo ""
    echo "  # 在 4.x 分支，自动同步到独立仓库的 4.x 分支"
    echo "  git checkout 4.x"
    echo "  ./scripts/sync-standalone.sh koatty-cli"
    echo ""
    echo "  # 手动指定目标分支"
    echo "  ./scripts/sync-standalone.sh koatty-cli --branch 3.12.x"
    echo ""
    echo "  # 指定自定义远程仓库"
    echo "  ./scripts/sync-standalone.sh koatty-cli --remote git@github.com:user/repo.git"
    echo ""
    echo -e "${BLUE}支持的包:${NC}"
    for package in "${!PACKAGE_REPOS[@]}"; do
        default_branch="${PACKAGE_DEFAULT_BRANCHES[$package]:-master}"
        echo "  - $package (默认分支: $default_branch)"
    done | sort
    echo ""
}

# 参数解析
PACKAGE_NAME=""
SPECIFIED_BRANCH=""
REMOTE_URL_ARG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --branch)
            SPECIFIED_BRANCH="$2"
            shift 2
            ;;
        --remote)
            REMOTE_URL_ARG="$2"
            shift 2
            ;;
        *)
            if [ -z "$PACKAGE_NAME" ]; then
                PACKAGE_NAME=$1
            else
                # 向后兼容：第二个参数作为远程 URL
                REMOTE_URL_ARG=$1
            fi
            shift
            ;;
    esac
done

# 参数检查
if [ -z "$PACKAGE_NAME" ]; then
    show_help
    exit 0
fi

PACKAGE_DIR="packages/$PACKAGE_NAME"
REMOTE_NAME="${PACKAGE_NAME}-standalone"

# 获取远程仓库 URL
if [ -n "$REMOTE_URL_ARG" ]; then
    REMOTE_URL=$REMOTE_URL_ARG
elif [ -n "${PACKAGE_REPOS[$PACKAGE_NAME]}" ]; then
    REMOTE_URL=${PACKAGE_REPOS[$PACKAGE_NAME]}
else
    echo -e "${RED}错误: 未知的包名 '$PACKAGE_NAME'${NC}"
    echo "请使用 --remote 指定远程仓库 URL 或使用支持的包名"
    show_help
    exit 1
fi

# 获取目标分支
TARGET_BRANCH=$(get_target_branch "$PACKAGE_NAME" "$SPECIFIED_BRANCH")

# 检查包目录是否存在
if [ ! -d "$PACKAGE_DIR" ]; then
    echo -e "${RED}错误: 包目录 $PACKAGE_DIR 不存在${NC}"
    exit 1
fi

# 获取 GitHub Token (仅 HTTPS URL 需要)
if [[ $REMOTE_URL =~ ^https:// ]]; then
    echo -e "${BLUE}检测到 HTTPS URL，需要 GitHub Token 认证${NC}"
    echo ""
    
    # 如果环境变量未设置，则调用函数获取
    if [ -z "$GITHUB_TOKEN" ]; then
        GITHUB_TOKEN=$(get_github_token)
    else
        echo -e "${GREEN}✓${NC} 使用环境变量中的 GITHUB_TOKEN"
    fi
    
    AUTHENTICATED_URL=$(build_authenticated_url "$REMOTE_URL" "$GITHUB_TOKEN")
    echo -e "${GREEN}✓${NC} Token 已配置"
    echo ""
else
    AUTHENTICATED_URL="$REMOTE_URL"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}同步 $PACKAGE_NAME 到独立仓库${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 显示当前 monorepo 分支
CURRENT_MONOREPO_BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "未知")
echo -e "${CYAN}当前 monorepo 分支:${NC} $CURRENT_MONOREPO_BRANCH"
echo -e "${CYAN}包目录:${NC} $PACKAGE_DIR"
echo -e "${CYAN}远程仓库:${NC} $REMOTE_URL"
echo -e "${CYAN}目标分支:${NC} ${GREEN}$TARGET_BRANCH${NC}"
if [ -n "$SPECIFIED_BRANCH" ]; then
    echo -e "${CYAN}分支来源:${NC} 手动指定"
elif [[ "$CURRENT_MONOREPO_BRANCH" == "main" ]] || [[ "$CURRENT_MONOREPO_BRANCH" == "master" ]]; then
    echo -e "${CYAN}分支来源:${NC} 默认配置"
else
    echo -e "${CYAN}分支来源:${NC} 自动检测（同名分支）"
fi
echo ""

# 检查是否有未提交的变更
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}警告: 检测到未提交的变更${NC}"
    echo ""
    git status --short
    echo ""
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 添加或更新 remote (使用认证后的 URL)
if git remote | grep -q "^${REMOTE_NAME}$"; then
    echo -e "${GREEN}✓${NC} Remote '${REMOTE_NAME}' 已存在"
    echo "  更新 remote URL..."
    git remote set-url "$REMOTE_NAME" "$AUTHENTICATED_URL"
else
    echo -e "${YELLOW}+${NC} 添加 remote '${REMOTE_NAME}'..."
    git remote add "$REMOTE_NAME" "$AUTHENTICATED_URL"
fi

echo ""
echo -e "${BLUE}开始同步...${NC}"
echo ""

# 生成同步分支名称（带时间戳）
SYNC_BRANCH="sync-from-monorepo-$(date +%Y%m%d-%H%M%S)"
TEMP_BRANCH="${PACKAGE_NAME}-sync-temp"

echo "1. 创建同步分支..."
git subtree split --prefix="$PACKAGE_DIR" -b "$TEMP_BRANCH"

echo ""
echo "2. 尝试推送到 $TARGET_BRANCH..."
# 尝试推送到目标分支
PUSH_OUTPUT=$(git push "$REMOTE_NAME" "$TEMP_BRANCH:$TARGET_BRANCH" --force 2>&1)
PUSH_STATUS=$?

if [ $PUSH_STATUS -eq 0 ]; then
    echo -e "${GREEN}✓${NC} 直接推送到 $TARGET_BRANCH 成功"
    NEED_PR=false
elif echo "$PUSH_OUTPUT" | grep -q "protected branch\|GH006"; then
    echo -e "${YELLOW}⚠${NC}  $TARGET_BRANCH 分支受保护，无法直接推送"
    echo -e "${BLUE}→${NC} 将创建 Pull Request..."
    NEED_PR=true
    
    # 推送到新分支
    echo ""
    echo "3. 推送到同步分支..."
    echo "  分支名称: $SYNC_BRANCH"
    if git push "$REMOTE_NAME" "$TEMP_BRANCH:$SYNC_BRANCH"; then
        echo -e "${GREEN}✓${NC} 推送到分支成功"
    else
        echo -e "${RED}✗${NC} 推送失败"
        echo "$PUSH_OUTPUT"
        git branch -D "$TEMP_BRANCH" 2>/dev/null || true
        exit 1
    fi
else
    echo -e "${RED}✗${NC} 推送失败"
    echo "$PUSH_OUTPUT"
    git branch -D "$TEMP_BRANCH" 2>/dev/null || true
    exit 1
fi

echo ""
echo "$([ "$NEED_PR" = true ] && echo "4" || echo "3"). 清理本地临时分支..."
git branch -D "$TEMP_BRANCH"

echo ""
STEP_NUM=$([ "$NEED_PR" = true ] && echo "5" || echo "4")
echo "$STEP_NUM. 同步 tags..."

# 获取与该包相关的 tags
PACKAGE_TAGS=$(git tag | grep "^${PACKAGE_NAME}@" || true)

if [ -n "$PACKAGE_TAGS" ]; then
    echo "  找到 ${PACKAGE_NAME} 的 tags:"
    echo "$PACKAGE_TAGS" | sed 's/^/    - /'
    
    # 为独立仓库创建不带包名前缀的 tags
    echo "  创建独立仓库格式的 tags..."
    for tag in $PACKAGE_TAGS; do
        # 提取版本号 (koatty-cli@1.0.0 -> v1.0.0)
        version=$(echo "$tag" | sed "s/^${PACKAGE_NAME}@//")
        standalone_tag="v${version}"
        
        # 获取该 tag 的 commit
        tag_commit=$(git rev-list -n 1 "$tag")
        
        # 在临时分支上创建新 tag
        if git tag "$standalone_tag" "$tag_commit" 2>/dev/null; then
            echo "    创建 tag: $standalone_tag"
        fi
    done
    
    # 推送 tags
    if git push "$REMOTE_NAME" --tags 2>&1 | grep -v "Everything up-to-date"; then
        echo -e "${GREEN}✓${NC} Tags 同步成功"
    else
        echo -e "${YELLOW}⚠${NC}  Tags 可能已存在或同步失败"
    fi
else
    echo -e "${YELLOW}⚠${NC}  未找到相关 tags"
fi

echo ""
STEP_NUM=$([ "$NEED_PR" = true ] && echo "6" || echo "5")
echo "$STEP_NUM. 清理认证信息..."

# 清理 remote 中的 token，恢复为原始 URL
if [[ $REMOTE_URL =~ ^https:// ]]; then
    git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
    echo -e "${GREEN}✓${NC} 已清理 remote 中的认证信息"
fi

# 如果不需要 PR，直接完成
if [ "$NEED_PR" = false ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ 同步完成!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}同步信息:${NC}"
    echo "  独立仓库: $REMOTE_URL"
    echo "  目标分支: $TARGET_BRANCH"
    echo "  同步方式: 直接推送"
    echo ""
    echo -e "${YELLOW}注意:${NC}"
    echo "  - 代码已直接推送到 $TARGET_BRANCH 分支"
    echo "  - Token 认证信息已从本地清理"
    echo ""
    exit 0
fi

# 提取仓库所有者和名称，用于构建 PR URL
REPO_OWNER=$(echo "$REMOTE_URL" | sed -n 's|.*github\.com[:/]\([^/]*\)/.*|\1|p')
REPO_NAME=$(echo "$REMOTE_URL" | sed -n 's|.*github\.com[:/][^/]*/\([^.]*\).*|\1|p')

echo ""
echo "7. 创建 Pull Request..."

# 获取最新的提交信息
LATEST_COMMIT_MSG=$(git log -1 --pretty=format:"%s" packages/"$PACKAGE_NAME" 2>/dev/null || echo "Sync from monorepo")

echo -e "${YELLOW}⚠${NC}  需要手动创建 Pull Request"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ 同步完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}同步信息:${NC}"
echo "  独立仓库: $REMOTE_URL"
echo "  同步分支: $SYNC_BRANCH"
echo "  目标分支: $TARGET_BRANCH"
echo "  同步方式: 创建 Pull Request"
echo ""
echo -e "${BLUE}下一步操作 - 创建 Pull Request:${NC}"
echo ""
echo "1. 访问以下链接创建 PR（推荐）:"
echo "   ${CYAN}https://github.com/$REPO_OWNER/$REPO_NAME/compare/$TARGET_BRANCH...$SYNC_BRANCH${NC}"
echo ""
echo "2. 创建 PR 时需要注意:"
echo "   - 标题建议: chore: Sync from monorepo - $(date +%Y-%m-%d)"
echo "   - 需要勾选 '${YELLOW}Allow edits from maintainers${NC}'"
echo ""
echo "3. 或使用 GitHub CLI 创建 PR:"
echo "   ${CYAN}gh pr create --repo $REPO_OWNER/$REPO_NAME \\${NC}"
echo "   ${CYAN}  --base $TARGET_BRANCH \\${NC}"
echo "   ${CYAN}  --head $SYNC_BRANCH \\${NC}"
echo "   ${CYAN}  --title \"chore: Sync from monorepo - $(date +%Y-%m-%d)\" \\${NC}"
echo "   ${CYAN}  --body \"从 koatty-cli-monorepo 同步最新代码\"${NC}"
echo ""
echo -e "${YELLOW}注意:${NC}"
echo "  - 同步分支已推送到独立仓库"
echo "  - 请手动创建并合并 PR"
echo "  - Token 认证信息已从本地清理"
echo ""

