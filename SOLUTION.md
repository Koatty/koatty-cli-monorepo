# Koatty CLI Monorepo 解决方案文档

## 项目概述

本项目是 Koatty 框架 CLI 工具的 Monorepo 仓库，旨在统一管理 CLI 工具及其相关模板包的开发、测试和发布流程。

## 技术架构

### 技术栈选型

#### 包管理器：pnpm
- **选择理由**：
  - 磁盘空间效率高，使用硬链接共享依赖
  - 安装速度快
  - 原生支持 monorepo workspace
  - 严格的依赖管理，避免幽灵依赖

#### 版本管理：Changesets
- **选择理由**：
  - 专为 monorepo 设计
  - 支持独立版本管理
  - 自动生成 changelog
  - 与 CI/CD 集成友好

#### 构建工具：tsup / tsc
- **koatty-cli**：使用 tsup 进行快速构建
- **其他包**：根据原有配置保持兼容

#### 代码质量工具
- **ESLint**：代码检查
- **Prettier**：代码格式化
- **husky + lint-staged**：提交前自动检查

### 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                   koatty-cli-monorepo                   │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌──────────────────┐
│ koatty-cli    │   │ koatty-       │   │ koatty-template- │
│               │───│ template      │   │ cli              │
│ (主 CLI 工具) │   │               │   │                  │
└───────────────┘   │ (项目模板)    │   │ (模块模板)       │
        │           └───────────────┘   └──────────────────┘
        │                   
        └───────────────────┐
                            ▼
                    ┌──────────────────┐
                    │ koatty-template- │
                    │ component        │
                    │                  │
                    │ (组件模板)       │
                    └──────────────────┘
```

## 包依赖关系

### koatty-cli
**依赖的模板包**：
- `koatty_template` (workspace:*)
- `koatty_template_cli` (workspace:*)
- `koatty_template_component` (workspace:*)

**主要功能**：
- 创建新项目（使用 koatty-template）
- 生成模块/文件（使用 koatty-template-cli）
- 创建组件（使用 koatty-template-component）

### koatty-template
**类型**：模板包，无代码依赖

**内容**：
- 完整的 Koatty 项目模板
- 包含配置文件、目录结构等

### koatty-template-cli
**类型**：模板包，无代码依赖

**内容**：
- Controller 模板
- Service 模板
- Middleware 模板
- 其他模块模板

### koatty-template-component
**类型**：模板包，无代码依赖

**内容**：
- 中间件组件模板
- 插件组件模板

## 功能模块

### 1. 项目创建 (koatty create)

**流程**：
```
用户执行命令
    ↓
CLI 收集信息（项目名、模板类型等）
    ↓
从 koatty-template 复制模板文件
    ↓
替换模板变量（如项目名）
    ↓
安装依赖
    ↓
完成创建
```

**模板类型**：
- Standard: 标准项目模板
- API: RESTful API 项目
- GraphQL: GraphQL API 项目
- Microservice: 微服务项目

### 2. 模块生成 (koatty generate)

**流程**：
```
用户执行命令（指定类型和名称）
    ↓
CLI 验证类型和名称
    ↓
从 koatty-template-cli 获取对应模板
    ↓
生成文件到指定目录
    ↓
完成生成
```

**支持的模块类型**：
- controller
- service
- middleware
- model
- dto
- config
- util

### 3. 组件创建 (koatty component)

**流程**：
```
用户执行命令（指定组件名和类型）
    ↓
CLI 收集信息
    ↓
从 koatty-template-component 复制模板
    ↓
替换模板变量
    ↓
生成完整的组件项目
    ↓
完成创建
```

**组件类型**：
- middleware: 中间件
- plugin: 插件

## 开发工作流

### 开发流程

1. **克隆仓库并安装依赖**
   ```bash
   git clone https://github.com/Koatty/koatty-cli-monorepo.git
   cd koatty-cli-monorepo
   pnpm install
   ```

2. **开发模式**
   ```bash
   # 监听所有包的变化并自动构建
   pnpm dev
   
   # 或者只监听特定包
   pnpm --filter koatty-cli run dev
   ```

3. **测试**
   ```bash
   # 运行所有测试
   pnpm test
   
   # 运行特定包的测试
   pnpm --filter koatty-cli run test
   ```

4. **提交代码**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   # 会自动触发 lint-staged 检查
   ```

### 发布流程

1. **添加变更集**
   ```bash
   pnpm changeset
   # 选择要发布的包
   # 选择版本类型（major/minor/patch）
   # 填写变更说明
   ```

2. **更新版本号**
   ```bash
   pnpm version
   # 会自动更新版本号并生成 CHANGELOG
   ```

3. **发布到 npm**
   ```bash
   pnpm release
   # 会先构建所有包，然后发布到 npm
   ```

## 配置说明

### pnpm-workspace.yaml
定义 workspace 包的位置：
```yaml
packages:
  - 'packages/*'
```

### 根 package.json
- 管理公共开发依赖
- 定义全局脚本命令
- 配置 engines 限制

### 子包 package.json
- 使用 `workspace:*` 引用本地包
- 配置 `publishConfig` 指定发布配置
- 定义包特定的脚本和依赖

### tsconfig.json
- 根目录提供基础 TypeScript 配置
- 子包通过 `extends` 继承基础配置
- 各包可覆盖特定配置项

## 最佳实践

### 1. 依赖管理
- **公共开发依赖**：安装在根目录
  ```bash
  pnpm add -D -w <package>
  ```
- **包特定依赖**：安装在对应包中
  ```bash
  pnpm --filter <package-name> add <dependency>
  ```
- **跨包引用**：使用 `workspace:*` 协议

### 2. 版本管理
- 使用 Changesets 管理版本
- 每次修改都添加 changeset
- 发布前统一更新版本号

### 3. 代码质量
- 提交前自动运行 lint 和 format
- 遵循 Conventional Commits 规范
- 编写单元测试覆盖核心功能

### 4. 构建优化
- 使用增量构建提高速度
- 利用 pnpm 的缓存机制
- 并行构建多个包

## 问题排查

### 依赖安装失败
```bash
# 清理缓存
pnpm store prune

# 删除 node_modules 和 lock 文件
rm -rf node_modules packages/*/node_modules pnpm-lock.yaml

# 重新安装
pnpm install
```

### 构建失败
```bash
# 清理构建产物
pnpm clean

# 重新构建
pnpm build
```

### 包引用问题
- 检查 pnpm-workspace.yaml 配置
- 确认使用 `workspace:*` 协议
- 运行 `pnpm install` 更新链接

## 未来规划

### 短期目标
- [ ] 完善 CLI 命令功能
- [ ] 添加更多项目模板
- [ ] 优化模板生成逻辑
- [ ] 增加单元测试覆盖率

### 长期目标
- [ ] 支持插件系统
- [ ] 提供可视化配置界面
- [ ] 集成 CI/CD 自动化流程
- [ ] 支持自定义模板仓库

## 参考资料

- [pnpm workspace](https://pnpm.io/workspaces)
- [Changesets 文档](https://github.com/changesets/changesets)
- [Monorepo 最佳实践](https://monorepo.tools/)
- [Koatty 框架文档](https://docs.koatty.com)

