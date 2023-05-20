// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
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

  function toString(address account) public pure returns(string memory) {
    return toString(abi.encodePacked(account));
  }
  function toString(bytes memory data) public pure returns(string memory) {
    bytes memory alphabet = "0123456789abcdef";

    bytes memory str = new bytes(2 + data.length * 2);
    str[0] = "0";
    str[1] = "x";
    for (uint i = 0; i < data.length; i++) {
      str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
      str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
    }
    return string(str);
  }

  function testChallenge() public {
    // 初始化常量
    address challenger = address(0x1111);
    uint256 startTime = 100;
    uint256 cycleDuration = 100;
    uint256 cycleCnt = 12;
    uint256 maxParticipants = 5;
    uint256 penaltyAmount = 100;
    uint256 initFund = 1000000;

    // 初始化参与者
    address[] memory participants = new address[](4);

    participants[0] = address(0x2222);
    participants[1] = address(0x3333);
    participants[2] = address(0x4444);
    participants[3] = address(0x5555);

    // 配置挑战
    vm.warp(0);
    blogChallenge.setChallenge(
      startTime, cycleDuration, cycleCnt,
      challenger, participants, maxParticipants,
      token, penaltyAmount
    );

    // 初始资金
    token.mint(challenger, initFund);
    assertEq(token.balanceOf(challenger), initFund);

    // 获取授权的金额
    uint256 approveAmount = blogChallenge.approveAmount();
    assertEq(approveAmount, (3 + cycleCnt) * penaltyAmount);

    uint256 depositAmount = blogChallenge.depositAmount();
    assertEq(depositAmount, 3 * penaltyAmount);

    // 给予 blogChallenge 扣费授权
    vm.prank(challenger);
    token.approve(address(blogChallenge), approveAmount);

    // 执行扣费
    vm.prank(challenger);
    blogChallenge.depositPenalty();
    assertEq(token.balanceOf(challenger), initFund - depositAmount);
    assertEq(blogChallenge.currentDeposit(), depositAmount);

    // 每个周期更新
    for (uint256 i = 0; i <= cycleCnt; i++) {
      vm.warp(startTime + cycleDuration * i + cycleDuration / 2);
      assertEq(blogChallenge.currentCycle(), i + 1);

      // 每次都提交推文
      if (i < cycleCnt) {
        vm.prank(challenger);
        blogChallenge.submitBlog("aaa");
      }

      // 更新周期
      if (i > 0) blogChallenge.updateCycle();
    }

    // 提取押金
//    vm.prank(challenger);
//    blogChallenge.withdrawDeposit();

    assertEq(token.balanceOf(challenger), initFund);
  }
}
