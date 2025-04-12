# 博客挑战智能合约

一个基于区块链技术的去中心化博客挑战平台，通过智能合约激励持续写博客。

[English](./README.md) | [产品文档](https://exermon-blog.notion.site/BlogChallenge-1d148ee5ba8d803da18cee4f22d63eec)

## 概述

博客挑战智能合约允许用户参与有经济激励的博客挑战。参与者可以质押代币，通过持续写博客获得奖励，如果错过截止日期则面临惩罚。

有关详细的产品规格和用户流程，请参阅我们的[产品文档](https://exermon-blog.notion.site/BlogChallenge-1d148ee5ba8d803da18cee4f22d63eec)。

### 主要特点

- **挑战管理**：创建和管理可自定义参数的博客挑战
- **代币系统**：内置ERC20代币系统用于管理质押和奖励
- **周期结构**：围绕博客周期组织，设有明确截止日期
- **惩罚机制**：针对错过博客发布的自动惩罚系统
- **参与者管理**：支持多人参与，具有白名单功能

## 技术栈

- Solidity ^0.8.4
- OpenZeppelin 合约库
- Hardhat & Foundry 开发环境
- TypeScript
- zkSync 集成

## 智能合约架构

`BlogChallenge` 合约继承自：
- `ERC20`：实现代币功能
- `ReentrancyGuard`：防止重入攻击

### 核心组件

- 挑战参数（周期、时间框架、惩罚）
- 参与者管理
- 博客提交跟踪
- 代币经济学
- 安全特性

## 开发设置

1. 安装依赖：
```bash
pnpm install
```

2. 编译合约：
```bash
pnpm compile
```

3. 运行测试：
```bash
pnpm test
```

## 可用脚本

- `compile`: 编译智能合约
- `test/hardhat`: 运行Hardhat测试
- `test/foundry`: 运行Foundry测试
- `deploy`: 部署主合约
- `deploy:token`: 部署代币合约
- `create`: 创建新挑战
- `participate`: 加入现有挑战
- `submit`: 提交博客文章
- `status`: 检查挑战状态

## 合约使用

### 创建挑战

可以使用以下参数创建挑战：
- 开始时间
- 周期时长
- 周期数量
- 惩罚代币和金额
- 最大参与人数
- 免费模式选项

### 参与方式

参与者可以通过以下方式加入挑战：
1. 获得白名单资格（如果需要）
2. 质押所需代币
3. 满足最低参与要求

### 提交博客

挑战者必须：
1. 在周期时间内提交博客
2. 包含标题、描述和URL
3. 保持持续发布以避免惩罚

### 奖励和惩罚

- 成功完成可获得参与者奖励
- 错过发布会触发惩罚
- 自动分配奖励/惩罚

## 安全特性

- ReentrancyGuard实现
- 基于角色的访问控制
- 安全的代币处理
- 自动化惩罚管理

## 许可证

ISC许可证
