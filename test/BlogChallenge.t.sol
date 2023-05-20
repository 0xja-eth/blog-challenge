// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "src/BlogChallenge.sol";

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
    uint256 startTime = 100;
    uint256 cycleDuration = 100;
    uint256 cycleCnt = 12;
    uint256 penaltyAmount = 100;
    uint256 fund = 1000000;

    address[] memory participants;

    participants.push(address(0x1111));
    participants.push(address(0x2222));
    participants.push(address(0x3333));

    token.mint(msg.sender, fund);

    vm.wrap(0);
    blogChallenge.setChallenge(
      startTime, cycleDuration, cycleCnt,
      msg.sender, participants,
      token, penaltyAmount
    );
    uint256 approveAmount = blogChallenge.approveAmount();
    assertEq(approveAmount, (3 + cycleCnt) * penaltyAmount);

    token.approve(approveAmount, blogChallenge);
    blogChallenge.depositPenalty();

    assertEq(token.balanceOf(msg.sender), fund - approveAmount);

    for (uint256 i = 0; i <= cycleCnt; i++) {
      vm.wrap(startTime + cycleDuration * i + cycleDuration / 2);
      if (i < cycleCnt) blogChallenge.submitBlog("aaa");
      if (i > 0) blogChallenge.updateCycle();
    }

    blogChallenge.withdrawDeposit();

    assertEq(token.balanceOf(msg.sender), fund);
  }
}
