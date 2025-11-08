# Koatty CLI Monorepo

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Node.js Version](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen.svg)](https://nodejs.org)

这是 Koatty 框架 CLI 工具的 Monorepo 仓库，包含了 CLI 工具主体以及相关的模板包。

## 📦 包含的项目

此 monorepo 包含以下包：

### 1. [koatty-cli](./packages/koatty-cli)
**Koatty 命令行工具**

主要的 CLI 工具，提供创建项目、生成模块、创建组件等功能。

- 📦 NPM: `koatty_cli`
- 🔗 GitHub: https://github.com/Koatty/koatty_cli.git

### 2. [koatty-template](./packages/koatty-template)
**项目模板**

用于创建新 Koatty 项目的模板文件，包含完整的项目结构和配置。

- 🔗 GitHub: https://github.com/Koatty/koatty_template.git

### 3. [koatty-template-cli](./packages/koatty-template-cli)
**CLI 模板**

用于生成项目模块或文件时使用的模板（如 Controller、Service、Middleware 等）。

- 📦 NPM: `koatty_template_cli`
- 🔗 GitHub: https://github.com/Koatty/koatty_template_cli.git

### 4. [koatty-template-component](./packages/koatty-template-component)
**组件模板**

用于创建独立中间件或插件的模板文件。

- 🔗 GitHub: https://github.com/Koatty/koatty_template_component.git

## 🚀 快速开始

### 环境要求

- Node.js >= 18.0.0
- pnpm >= 8.0.0

### 安装依赖

```bash
# 安装 pnpm（如果尚未安装）
npm install -g pnpm

# 克隆仓库
git clone https://github.com/Koatty/koatty-cli-monorepo.git
cd koatty-cli-monorepo

# 安装所有依赖
pnpm install
```

### 构建项目

```bash
# 构建所有包
pnpm build

# 开发模式（监听文件变化）
pnpm dev
```

### 运行测试

```bash
# 运行所有包的测试
pnpm test

# 代码检查
pnpm lint

# 代码格式化
pnpm format
```

## 📦 发布管理

### 发布新版本

```bash
# 发布 koatty-cli 新版本
./scripts/release.sh koatty-cli minor --sync

# 或使用 pnpm
pnpm release:minor koatty-cli --sync
```

### 同步到独立仓库

```bash
# 设置 GitHub Token
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx

# 自动检测当前分支并同步
./scripts/sync-standalone.sh koatty-cli

# 手动指定目标分支
./scripts/sync-standalone.sh koatty-cli --branch 4.x
```

### 🌳 多分支支持

支持在不同分支开发并自动同步到对应的独立仓库分支：

```bash
# 在 4.x 分支开发
git checkout 4.x
./scripts/release.sh koatty-cli minor --sync
# → 自动同步到独立仓库的 4.x 分支

# 在 3.12.x 分支维护
git checkout 3.12.x
./scripts/release.sh koatty-cli patch --sync
# → 自动同步到独立仓库的 3.12.x 分支
```

📚 **完整发布指南**: [RELEASE_GUIDE.md](./RELEASE_GUIDE.md)

📜 **脚本文档**: [scripts/README.md](./scripts/README.md)

🌳 **多分支开发**: [MULTI_BRANCH_GUIDE.md](./MULTI_BRANCH_GUIDE.md)

## 📖 开发指南

### Monorepo 结构

```
koatty-cli-monorepo/
├── packages/
│   ├── koatty-cli/              # CLI 工具主体
│   ├── koatty-template/         # 项目模板
│   ├── koatty-template-cli/     # 模块/文件模板
│   └── koatty-template-component/  # 组件模板
├── package.json                 # 根 package.json
├── pnpm-workspace.yaml          # pnpm workspace 配置
├── tsconfig.json                # TypeScript 基础配置
└── README.md                    # 项目说明
```

### 包管理

本项目使用 pnpm workspace 管理 monorepo。所有子包通过 `workspace:*` 协议相互引用。

#### 添加依赖

```bash
# 为特定包添加依赖
pnpm --filter koatty-cli add <package-name>

# 为所有包添加开发依赖
pnpm -r add -D <package-name>

# 在根目录添加公共开发依赖
pnpm add -D -w <package-name>
```

#### 运行命令

```bash
# 在特定包中运行命令
pnpm --filter koatty-cli run build

# 在所有包中运行命令
pnpm -r run test
```

### 版本管理

本项目使用 [Changesets](https://github.com/changesets/changesets) 进行版本管理。

```bash
# 添加变更集
pnpm changeset

# 更新版本号
pnpm version

# 发布包
pnpm release
```

### 本地开发

由于各个包之间可能存在依赖关系，建议按以下顺序开发：

1. **koatty-template-***：首先开发模板包
2. **koatty-cli**：然后开发 CLI 工具，引用模板包

在 CLI 包中，可以通过 `workspace:*` 引用本地的模板包：

```json
{
  "dependencies": {
    "koatty_template": "workspace:*",
    "koatty_template_cli": "workspace:*",
    "koatty_template_component": "workspace:*"
  }
}
```

### 代码规范

- 使用 ESLint 进行代码检查
- 使用 Prettier 进行代码格式化
- 提交前会自动运行 lint-staged

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 提交信息规范

本项目遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建或辅助工具变动

## 📄 许可证

[MIT](LICENSE)

## 👥 维护者

- [richenlin](https://github.com/richenlin)

## 🔗 相关链接

- [Koatty 官网](https://koatty.com)
- [Koatty 文档](https://docs.koatty.com)
- [Koatty GitHub](https://github.com/Koatty/koatty)

## 📮 问题反馈

如果您在使用过程中遇到问题，欢迎提交 [Issue](https://github.com/Koatty/koatty-cli-monorepo/issues)。

