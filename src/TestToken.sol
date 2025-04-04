// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        // 为部署者铸造 1000000 枚代币
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(uint256 amount) external {
        // 任何人都可以铸造代币
        _mint(msg.sender, amount);
    }
}
