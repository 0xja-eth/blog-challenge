# Blog Challenge Smart Contract

A decentralized blog challenge platform built on blockchain technology that incentivizes consistent blogging through smart contracts using a penalty mechanism.

[中文文档](./README.zh-CN.md) | [Product Documentation](https://exermon-blog.notion.site/BlogChallenge-Product-Description-1d348ee5ba8d80d8a18edc78200bfe11)

For detailed product specifications and user flows, please refer to our [Product Documentation](https://exermon-blog.notion.site/BlogChallenge-Product-Description-1d348ee5ba8d80d8a18edc78200bfe11).

## Technical Stack

- Solidity ^0.8.4
- OpenZeppelin Contracts
- Hardhat & Foundry Development Environment
- TypeScript
- zkSync Integration

## Smart Contract Architecture

The project implements a factory pattern with two main contracts:

### ChallengeFactory Contract

The factory contract is responsible for:
- Creating and managing BlogChallenge instances
- Tracking all created challenges
- Maintaining challenger-to-challenge mappings
- Implementing upgradeable challenge implementation using CREATE2

Key features:
- Uses CREATE2 for deterministic address generation
- Supports challenge implementation upgrades
- Maintains a registry of all challenges
- Owned by a contract administrator

### BlogChallenge Contract

Each challenge instance is an ERC20 token contract with the following features:

1. **State Management**:
   - Not Started → Started → Ended
   - Transitions triggered by time and user actions
   - Automatic cycle updates and penalty distribution

2. **Core Components**:
   - Challenge Parameters (cycles, timeframes, penalties)
   - Participant Management with whitelist support
   - Blog Submission Tracking with cycle-based structure
   - Token Economics for stake management
   - Automated Penalty Distribution System

3. **Security Features**:
   - ReentrancyGuard for transaction safety
   - Role-based access control
   - Safe token handling with approve-transfer pattern
   - Automated state transitions

4. **Token Economics**:
   - Initial supply: 1M tokens
   - Deposit multiplier: 3x penalty amount
   - Minimum participation requirements
   - Automatic penalty distribution based on stake

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