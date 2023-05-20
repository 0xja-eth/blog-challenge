// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "..\src\BlogChallenge.sol";

contract BaseERC20 is ERC20 {
  constructor() ERC20("Base", "Base") {}

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }
}

contract BlogChallengeTest is Test {
  BlogChallenge blogChallenge;
  BaseERC20 token;

  function setUp() public {
    blogChallenge = new BlogChallenge();
    token = new BaseERC20();
  }

  function testChallenge() {
    uint256 cycleCnt = 12;
    uint256 tokenAmount = 100;
    address[] memory participants;

    participants.push(address(0x1111));
    participants.push(address(0x2222));
    participants.push(address(0x3333));

    token.mint(msg.sender, 1000000);

    vm.wrap(0);
    blogChallenge.setChallenge(
      100, 100, cycleCnt,
      msg.sender, participants,
      token, tokenAmount
    );
    uint256 approveAmount = blogChallenge.approveAmount();

    token.approve(approveAmount, blogChallenge);
    blogChallenge.depositPenalty();

    for (uint256 i = 0; i < cycleCnt; i++) {

    }

    vm.wrap(150);

  }
}
