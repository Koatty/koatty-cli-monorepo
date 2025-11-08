# 脚本使用说明

本目录包含用于发布和同步 Koatty CLI Monorepo 包的脚本。

## 📜 脚本列表

### 1. release.sh - 发布脚本

统一的包发布脚本，用于版本管理、npm 发布和 Git 标签创建。

#### 使用方法

```bash
./scripts/release.sh <package-name> [release-type] [options]
```

#### 参数说明

**Package Name（必需）：**
- `koatty-cli` - CLI 工具主体
- `koatty-template` - 项目模板
- `koatty-template-cli` - 模块/文件模板
- `koatty-template-component` - 组件模板

**Release Type（可选，默认 patch）：**
- `patch` - 补丁版本（1.0.0 → 1.0.1）
- `minor` - 次版本（1.0.0 → 1.1.0）
- `major` - 主版本（1.0.0 → 2.0.0）
- `prerelease` - 预发布版本（1.0.0 → 1.0.1-0）

**选项：**
- `--dry-run` - 模拟运行，不实际执行
- `--sync` - 发布成功后自动同步到独立仓库
- `--no-npm` - 跳过 npm 发布，仅更新版本

#### 使用示例

```bash
# 发布 koatty-cli 的 patch 版本
./scripts/release.sh koatty-cli

# 发布 koatty-cli 的 minor 版本
./scripts/release.sh koatty-cli minor

# 发布 koatty-cli 的 major 版本并自动同步
./scripts/release.sh koatty-cli major --sync

# 模拟发布流程（不实际执行）
./scripts/release.sh koatty-cli --dry-run

# 仅更新版本，不发布到 npm
./scripts/release.sh koatty-template --no-npm

# 发布预发布版本
./scripts/release.sh koatty-cli prerelease
```

#### 使用 npm/pnpm 命令

```bash
# 使用 pnpm 发布（推荐）
pnpm release koatty-cli          # patch 版本
pnpm release:minor koatty-cli    # minor 版本
pnpm release:major koatty-cli    # major 版本
pnpm release:pre koatty-cli      # prerelease 版本
```

#### 发布流程

脚本会执行以下步骤：

1. **运行测试** - 确保代码质量
2. **更新版本** - 使用 standard-version 更新版本号和 CHANGELOG
3. **发布到 npm** - 将包发布到 npm（CLI 包，模板包跳过）
4. **推送到 Git** - 推送代码和标签到远程仓库
5. **同步到独立仓库** - （如果使用 `--sync` 选项）

#### 注意事项

- **koatty-cli**: 会发布到 npm
- **模板包**: 不会发布到 npm，仅更新版本
- 发布前需要登录 npm: `npm login`
- 标签格式：`<package-name>@<version>`（如：`koatty-cli@3.12.3`）

---

### 2. sync-standalone.sh - 同步脚本

将 monorepo 中的包同步到独立的 GitHub 仓库。**支持多分支开发，自动检测当前分支并同步到同名分支。**

#### 使用方法

```bash
./scripts/sync-standalone.sh <package-name> [options]
```

#### 选项

- `--branch <branch>` - 指定目标分支（默认：自动检测当前分支）
- `--remote <url>` - 指定远程仓库 URL

#### 环境变量

**GITHUB_TOKEN** - GitHub Personal Access Token

用于 HTTPS 认证，避免每次手动输入。可以通过以下方式设置：

```bash
# 方式 1: 设置环境变量
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx

# 方式 2: 创建 .github-token 文件
echo 'ghp_xxxxxxxxxxxxx' > .github-token

# 方式 3: 脚本运行时手动输入
```

#### 创建 GitHub Token

1. 访问：https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 选择权限：`repo`（完整访问）
4. 生成并复制 Token

#### 使用示例

```bash
# 基本用法：自动检测分支并同步
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
./scripts/sync-standalone.sh koatty-cli

# 在 4.x 分支，自动同步到独立仓库的 4.x 分支
git checkout 4.x
./scripts/sync-standalone.sh koatty-cli

# 手动指定目标分支
./scripts/sync-standalone.sh koatty-cli --branch 3.12.x

# 使用自定义仓库 URL
./scripts/sync-standalone.sh koatty-cli --remote git@github.com:user/repo.git

# 组合使用
./scripts/sync-standalone.sh koatty-cli --branch 4.x --remote https://...

# 使用 pnpm 命令
pnpm sync koatty-cli
```

#### 同步流程

脚本会执行以下操作：

1. **验证包目录** - 检查包是否存在
2. **配置认证** - 获取 GitHub Token（如需要）
3. **创建同步分支** - 使用 git subtree 提取包代码
4. **推送到远程** - 推送到独立仓库
5. **同步标签** - 同步相关的 Git 标签
6. **清理认证信息** - 从本地配置中清理 Token

#### 分支策略（多分支支持）

**自动分支检测规则：**

1. **如果指定 `--branch`**：使用指定的分支
2. **如果当前在 `main` 或 `master` 分支**：使用配置的默认分支
3. **如果当前在其他分支（如 `4.x`）**：自动同步到独立仓库的同名分支

**默认分支配置**（当在 main/master 时使用）：

- **koatty-cli**: `3.12.x` 分支 ⭐
- **koatty-template**: `master` 分支
- **koatty-template-cli**: `master` 分支
- **koatty-template-component**: `master` 分支

**多分支示例：**

```bash
# 场景 1: 在 4.x 分支开发
git checkout 4.x
./scripts/sync-standalone.sh koatty-cli
# → 自动同步到独立仓库的 4.x 分支

# 场景 2: 在 main 分支
git checkout main
./scripts/sync-standalone.sh koatty-cli
# → 同步到配置的默认分支 3.12.x

# 场景 3: 手动指定
git checkout 5.0.x
./scripts/sync-standalone.sh koatty-cli --branch 5.0.x
# → 同步到指定的 5.0.x 分支
```

📖 **详细说明**: 查看 [MULTI_BRANCH_GUIDE.md](../MULTI_BRANCH_GUIDE.md)

#### 同步模式

**直接推送模式：**
- 如果目标分支没有保护，直接推送代码
- 自动完成同步

**Pull Request 模式：**
- 如果目标分支受保护，创建同步分支
- 需要手动创建 PR 并合并
- 脚本会提供 PR 创建链接

---

## 🔄 完整工作流示例

### 发布新版本并同步

```bash
# 1. 在 monorepo 中开发和提交代码
git add .
git commit -m "feat: add new feature"

# 2. 发布新版本并自动同步
./scripts/release.sh koatty-cli minor --sync

# 3. （可选）如果没有使用 --sync，手动同步
./scripts/sync-standalone.sh koatty-cli
```

### 仅同步现有代码

```bash
# 同步 koatty-cli 到独立仓库
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
./scripts/sync-standalone.sh koatty-cli
```

### 模拟发布流程

```bash
# 在不实际发布的情况下查看将会发生什么
./scripts/release.sh koatty-cli minor --dry-run
```

---

## ⚙️ 配置说明

### 包映射配置

两个脚本都包含包名到仓库的映射：

```bash
# release.sh 和 sync-standalone.sh 中的配置
declare -A PACKAGE_REPOS=(
    ["koatty-cli"]="https://github.com/Koatty/koatty_cli.git"
    ["koatty-template"]="https://github.com/Koatty/koatty_template.git"
    ["koatty-template-cli"]="https://github.com/Koatty/koatty_template_cli.git"
    ["koatty-template-component"]="https://github.com/Koatty/koatty_template_component.git"
)
```

### 分支映射配置

```bash
# 各包的目标分支
declare -A PACKAGE_BRANCHES=(
    ["koatty-cli"]="3.12.x"      # 特殊分支
    ["koatty-template"]="master"
    ["koatty-template-cli"]="master"
    ["koatty-template-component"]="master"
)
```

---

## 🔐 安全注意事项

### GitHub Token 安全

1. **不要提交 Token 到 Git**
   - `.github-token` 文件已在 `.gitignore` 中
   - 不要在脚本中硬编码 Token

2. **Token 权限最小化**
   - 只给予必要的 `repo` 权限
   - 定期轮换 Token

3. **Token 存储**
   - 使用环境变量（推荐）
   - 或使用 `.github-token` 文件（本地开发）
   - 不要在公共环境中存储 Token

### 脚本安全

- 脚本会在退出时自动清理认证信息
- HTTPS URL 中的 Token 会在操作完成后移除

---

## 🐛 故障排查

### 问题：脚本没有执行权限

```bash
# 添加执行权限
chmod +x scripts/*.sh
```

### 问题：未安装 standard-version

```bash
# 全局安装
pnpm add -g standard-version

# 或在项目中安装
pnpm add -D standard-version
```

### 问题：Git 认证失败

```bash
# 检查 Token 是否有效
echo $GITHUB_TOKEN

# 测试 Token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# 重新生成 Token
# https://github.com/settings/tokens
```

### 问题：推送被拒绝（分支保护）

这是正常情况，脚本会自动切换到 PR 模式：

1. 脚本会创建同步分支
2. 显示 PR 创建链接
3. 手动访问链接创建 PR
4. 审核并合并 PR

### 问题：同步时历史不兼容

使用 `git subtree split` 会创建新的提交历史，这是正常的：

- 独立仓库保持自己的历史
- Monorepo 保持自己的历史
- 通过定期同步保持代码一致

---

## 📚 相关资源

- [Standard Version 文档](https://github.com/conventional-changelog/standard-version)
- [Git Subtree 文档](https://git-scm.com/book/en/v2/Git-Tools-Subtrees)
- [GitHub Tokens 文档](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

## 💡 最佳实践

1. **发布前**
   - 确保所有测试通过
   - 检查 CHANGELOG 是否正确
   - 使用 `--dry-run` 预览变更

2. **版本管理**
   - 遵循语义化版本（Semver）
   - 使用 Conventional Commits 规范
   - 保持 CHANGELOG 更新

3. **同步策略**
   - 发布后立即同步（使用 `--sync`）
   - 或定期批量同步
   - 保持 monorepo 和独立仓库的一致性

4. **协作开发**
   - 主要在 monorepo 中开发
   - 独立仓库作为发布和分发渠道
   - 通过脚本自动同步，避免手动操作

