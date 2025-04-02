# Blog Challenge Contract

这是一个基于智能合约的博客写作挑战系统。用户可以创建挑战，设定挑战周期和奖励，其他用户可以参与挑战并获得奖励。

## 安装

```bash
npm install
```

## 编译合约

```bash
npm run compile
```

## 测试

```bash
# 运行所有测试
npm test

# 只运行 Hardhat 测试
npm run test/hardhat

# 只运行 Foundry 测试
npm run test/foundry
```

## 部署合约

```bash
# 部署合约
npm run deploy

# 创建新的挑战
npm run create

# 参与挑战
npm run participate <挑战地址> [份额(基点)]

# 提交博客
npm run submit <挑战地址> <标题> <描述> <URL>

# 查看挑战状态
npm run status <挑战地址>
```

## 合约说明

### BlogChallenge

博客挑战合约，主要功能：

1. 创建挑战：设定挑战周期、奖励代币等参数
2. 参与挑战：其他用户可以参与挑战并获得奖励代币
3. 提交博客：挑战者需要在每个周期内提交博客
4. 检查状态：查看挑战进度、参与者信息等

### ChallengeFactory

挑战工厂合约，用于创建新的挑战。

## 环境变量

创建 `.env` 文件并设置以下环境变量：

```bash
# 网络设置
DEFAULT_ENV=test # 或 dev, prod

# 私钥（用于部署和交易）
PRIVATE_KEY=your_private_key

# RPC URL
DEV_URL=http://localhost:8545
TEST_URL=https://your_testnet_rpc
PROD_URL=https://your_mainnet_rpc
```

## 脚本使用示例

1. 创建新的挑战：

```bash
npm run create
```

2. 参与挑战（50% 份额）：

```bash
npm run participate 0x123...abc 5000
```

3. 提交博客：

```bash
npm run submit 0x123...abc "我的第一篇博客" "这是一篇测试博客" "https://example.com/blog/1"
```

4. 查看挑战状态：

```bash
npm run status 0x123...abc
```
