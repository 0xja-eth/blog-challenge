# Blog Challenge Smart Contract

A decentralized blog challenge platform built on blockchain technology that incentivizes consistent blogging through smart contracts.

[中文文档](./README.zh-CN.md) | [Product Documentation](https://exermon-blog.notion.site/BlogChallenge-Product-Description-1d348ee5ba8d80d8a18edc78200bfe11)

## Overview

The Blog Challenge smart contract allows users to participate in blogging challenges with financial incentives. Participants can stake tokens and earn rewards for consistent blogging, while facing penalties for missing deadlines.

For detailed product specifications and user flows, please refer to our [Product Documentation](https://exermon-blog.notion.site/BlogChallenge-Product-Description-1d348ee5ba8d80d8a18edc78200bfe11).

### Key Features

- **Challenge Management**: Create and manage blogging challenges with customizable parameters
- **Token System**: Built-in ERC20 token system for managing stakes and rewards
- **Cycle-based Structure**: Organized around blogging cycles with clear deadlines
- **Penalty Mechanism**: Automated penalty system for missed blog posts
- **Participant Management**: Support for multiple participants with whitelist functionality

## Technical Stack

- Solidity ^0.8.4
- OpenZeppelin Contracts
- Hardhat & Foundry Development Environment
- TypeScript
- zkSync Integration

## Smart Contract Architecture

The `BlogChallenge` contract inherits from:
- `ERC20`: For token functionality
- `ReentrancyGuard`: For security against reentrancy attacks

### Key Components

- Challenge Parameters (cycles, timeframes, penalties)
- Participant Management
- Blog Submission Tracking
- Token Economics
- Security Features

## Development Setup

1. Install dependencies:
```bash
pnpm install
```

2. Compile contracts:
```bash
pnpm compile
```

3. Run tests:
```bash
pnpm test
```

## Available Scripts

- `compile`: Compile smart contracts
- `test/hardhat`: Run Hardhat tests
- `test/foundry`: Run Foundry tests
- `deploy`: Deploy the main contract
- `deploy:token`: Deploy the token contract
- `create`: Create a new challenge
- `participate`: Join an existing challenge
- `submit`: Submit a blog post
- `status`: Check challenge status

## Contract Usage

### Creating a Challenge

A challenge can be created with the following parameters:
- Start time
- Cycle duration
- Number of cycles
- Penalty token and amount
- Maximum participants
- Free mode option

### Participating

Participants can join challenges by:
1. Getting whitelisted (if required)
2. Staking required tokens
3. Meeting minimum participation requirements

### Submitting Blogs

Challengers must:
1. Submit blogs within their cycle timeframe
2. Include title, description, and URL
3. Maintain consistent posting to avoid penalties

### Rewards and Penalties

- Successful completion rewards participants
- Missed posts trigger penalties
- Automatic distribution of rewards/penalties

## Security Features

- ReentrancyGuard implementation
- Role-based access control
- Safe token handling
- Automated penalty management

## License

ISC License