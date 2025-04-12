# 博客挑战智能合约

一个基于区块链技术的去中心化博客挑战平台，通过智能合约惩罚的方式激励挑战者持续写博客。

[English](./README.md) | [产品文档](https://exermon-blog.notion.site/BlogChallenge-1d148ee5ba8d803da18cee4f22d63eec)

有关详细的产品规格和用户流程，请参阅我们的[产品文档](https://exermon-blog.notion.site/BlogChallenge-1d148ee5ba8d803da18cee4f22d63eec)。

## 技术栈

- Solidity ^0.8.4
- OpenZeppelin 合约库
- Hardhat & Foundry 开发环境
- TypeScript
- zkSync 集成

## 智能合约架构

项目采用工厂模式实现，包含两个主要合约：

### ChallengeFactory 合约

工厂合约负责：
- 创建和管理 BlogChallenge 实例
- 追踪所有已创建的挑战
- 维护挑战者与挑战的映射关系
- 使用 CREATE2 实现可升级的挑战合约实现

主要特点：
- 使用 CREATE2 实现确定性地址生成
- 支持挑战合约实现的升级
- 维护所有挑战的注册表
- 由合约管理员拥有权限控制

### BlogChallenge 合约

每个挑战实例都是一个 ERC20 代币合约，具有以下特点：

1. **状态管理**：
   - 未开始 → 进行中 → 已结束
   - 由时间和用户行为触发状态转换
   - 自动的周期更新和惩罚分发

2. **核心组件**：
   - 挑战参数（周期、时间框架、惩罚）
   - 支持白名单的参与者管理
   - 基于周期的博客提交跟踪
   - 代币经济学质押管理
   - 自动化惩罚分发系统

3. **安全特性**：
   - ReentrancyGuard 防重入保护
   - 基于角色的访问控制
   - 使用 approve-transfer 模式的安全代币处理
   - 自动化的状态转换

4. **代币经济学**：
   - 初始供应量：100万代币
   - 保证金倍数：惩罚金额的3倍
   - 最低参与要求
   - 基于质押比例的自动惩罚分发

## 开发设置

1. 安装依赖：
```bash
pnpm install
```

2. 设置环境变量：

首先，设置根环境文件：
```bash
cp .env.example .env
```

在 `.env` 文件中配置以下内容：
- `CHAIN`：目标区块链网络（如 optimism、arbitrum）
- `DEFAULT_ENV`：网络环境（可选值为 `dev`, `test`, `main`）
- `PRIVATE_KEY`：默认部署私钥
- `DEVNET_PRIVATE_KEY`：开发网络私钥
- `TESTNET_PRIVATE_KEY`：测试网络私钥
- `MAINNET_PRIVATE_KEY`：主网私钥
- `CONTRACT_CACHE_FILE`：合约缓存文件路径

然后，根据您在 `.env` 中选择的 `CHAIN` 设置对应的链特定环境文件：
```bash
# 如果 .env 中设置了 CHAIN=optimism
cp env/optimism.env.example env/optimism.env
# 如果 .env 中设置了 CHAIN=arbitrum
cp env/arbitrum.env.example env/arbitrum.env
```

在链特定环境文件中配置以下内容：
- 各网络的链 ID
- 各网络的 RPC URL
- 网络特定的私钥
- 区块浏览器验证 URL
3. 编译合约：
```bash
pnpm compile
```

4. 运行测试：
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
