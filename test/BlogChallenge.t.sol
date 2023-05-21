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

  address challenger = address(0x1111);
  uint256 startTime = 100;
  uint256 cycleDuration = 100;
  uint256 cycleCnt = 12;
  uint256 maxParticipants = 5;
  uint256 penaltyAmount = 100;
  uint256 initFund = 1000000;

  address[] participants;

  // region events

  event ChallengeStart(address indexed challenger);
  event ChallengeEnd(address indexed challenger, bool indexed passed);

  event SubmitBlog(address indexed challenger, uint256 indexed cycle, string blogUrl);
  event CycleEnd(address indexed challenger, uint256 indexed cycle, bool indexed passed);

  event Participate(address indexed challenger, address indexed participant);
  event Exit(address indexed challenger, address indexed participant);

  event Release(address indexed challenger, uint256 indexed cycle, uint256 amount);

  // endregion

  function setUp() public {
    blogChallenge = new BlogChallenge();
    token = new BaseERC20();

    participants.push(address(0x2222));
    participants.push(address(0x3333));
    participants.push(address(0x4444));
    participants.push(address(0x5555));
  }

  function initialize() private {
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
  }

  // 授权扣费
  function approve() private {
    // 获取授权的金额
    uint256 approveAmount = blogChallenge.approveAmount();
    assertEq(approveAmount, (3 + cycleCnt) * penaltyAmount);

    // 给予 blogChallenge 扣费授权
    vm.prank(challenger);
    token.approve(address(blogChallenge), approveAmount);

    assertEq(blogChallenge.isChallengerApproved(), true);
  }

  // 取消授权扣费
  function cancelApprove() private {
    uint256 approveAmount = token.allowance(challenger, address(blogChallenge));
    vm.prank(challenger);
    token.decreaseAllowance(address(blogChallenge), approveAmount);
  }

  // 存入押金
  function depositPenalty() private {
    // 先授权扣费
    approve();

    // 获取押金的金额
    uint256 depositAmount = blogChallenge.depositAmount();
    assertEq(depositAmount, 3 * penaltyAmount);

    // 执行扣费
    vm.prank(challenger);
    blogChallenge.depositPenalty();

    assertEq(token.balanceOf(challenger), initFund - depositAmount);
    assertEq(blogChallenge.currentDeposit(), depositAmount);
  }

  // 跳转到周期
  function jumpToCycle(uint256 cycleIdx) private {
    jumpToCycle(cycleIdx, cycleDuration / 2);
  }
  function jumpToCycle(uint256 cycleIdx, uint256 offset) private {
    vm.warp(startTime + cycleDuration * cycleIdx + offset);
  }

  // 提交博文
  function submitBlog(string memory blogUrl) private {
    uint256 cycle = blogChallenge.currentCycle();

    vm.prank(challenger);

    vm.expectEmit(true, true, false, true);
    emit SubmitBlog(challenger, cycle, blogUrl);

    blogChallenge.submitBlog(blogUrl);
  }

  // 更新周期
  function updateCycle(uint256 cycleIdx, bool submit) private {
    if (cycleIdx >= cycleCnt) return updateLastCycle();

    jumpToCycle(cycleIdx);

    // 每次都提交推文
    if (submit) submitBlog("aaa");

    // 更新周期
    if (cycleIdx > 0) {
      vm.expectEmit(true, true, false, true);
      // cycleIdx是指上一个cycle，当前cycle还没结束
      emit CycleEnd(challenger, cycleIdx, submit);
      blogChallenge.updateCycle();
    }
  }
  // 处理中途结束时候的ChallengeEnd事件判断
  function updateCycle(uint256 cycleIdx, bool submit, bool passChallenge) private {
    jumpToCycle(cycleIdx);

    // 每次都提交推文
    if (cycleIdx < cycleCnt && submit) submitBlog("aaa");

    // 更新周期
    if (cycleIdx > 0) {
      vm.expectEmit(true, false, false, true);
      emit ChallengeEnd(challenger, passChallenge);
      blogChallenge.updateCycle();
    }
  }

  // 更新最后周期，校验挑战结束事件
  function updateLastCycle(bool passChallenge) private {
    jumpToCycle(cycleCnt);

    vm.expectEmit(true, false, false, true);
    emit ChallengeEnd(challenger, passChallenge);
    blogChallenge.updateCycle();
  }
  function updateLastCycle() private {
    updateLastCycle(blogChallenge.checkSuccess());
  }

  function testChallenge() public {
    initialize();
    depositPenalty();

    // 每个周期更新
    for (uint256 i = 0; i <= cycleCnt; i++)
      updateCycle(i, true);

    assertEq(token.balanceOf(challenger), initFund);
  }

  function testNotDeposit() public {
    initialize();
    // depositPenalty();
    updateCycle(1, true, false); // 会直接导致挑战失败

    vm.expectRevert("Not started");
    blogChallenge.updateCycle();
  }

  function testCycleFailed() public {
    initialize();
    depositPenalty();

    uint256 curFund = token.balanceOf(challenger);

    require(blogChallenge.isChallengerApproved(), "Challenger not approved");

    for (uint256 i = 0; i <= cycleCnt; i++) {
      updateCycle(i, false);

      // 检查是否扣费
      if (i < cycleCnt) // i == cycleCnt 时，押金已经退了，所以不需要再检查了
        require(
          token.balanceOf(challenger) == curFund - penaltyAmount * i,
          toString((1 << 96) +(i << 64) +
        ((curFund - penaltyAmount * i) << 32) +
          token.balanceOf(challenger)
          ));

      // 检查奖励是否平均发放
      uint256 len = participants.length;
      uint256 part = penaltyAmount / len; // 一份奖励
      for (uint256 j = 0; j < len; j++)
        require(
          token.balanceOf(participants[j]) == part * i,
          toString((2 << 96) + (i << 64) +
            (token.balanceOf(participants[j]) << 32) +
            (part * i)
          ));
    }

    // 检查是否退回了押金
    assertEq(token.balanceOf(challenger), initFund - penaltyAmount * cycleCnt);
  }

  function testMultUpdate() public {
    initialize();
    depositPenalty();

    updateCycle(0, true);

    jumpToCycle(1);
    blogChallenge.updateCycle();

    jumpToCycle(1);
    vm.expectRevert("All cycles are updated!");
    blogChallenge.updateCycle();

    // 多测试几次
    jumpToCycle(2);
    blogChallenge.updateCycle();

    jumpToCycle(3);
    blogChallenge.updateCycle();
    jumpToCycle(3);
    vm.expectRevert("All cycles are updated!");
    blogChallenge.updateCycle();
  }

  function testCancelApprove() public {
    initialize();
    depositPenalty();

    uint256 depositAmount = blogChallenge.depositAmount();

    uint256 len = participants.length;
    uint256 part = penaltyAmount / len; // 一份奖励

    updateCycle(0, true);
    updateCycle(1, true);

    cancelApprove();
    updateCycle(2, false);

    // 因为提交了博文，这里不会扣费
    assertEq(blogChallenge.currentDeposit(), depositAmount);

    updateCycle(3, true);

    // 没有提交博文，产生扣费，因为取消了授权，扣除押金
    uint256 restDeposit = blogChallenge.currentDeposit();
    assertEq(restDeposit, depositAmount - penaltyAmount);
    for (uint256 j = 0; j < len; j++)
      assertEq(token.balanceOf(participants[j]), part);

    updateCycle(4, false); // 第三周期有提交博文，可以继续进行

    // 两次没有提交博文，挑战结束
    // 检查ChallengeEnd
    updateCycle(5, false, false);

    // 直接扣除全部押金
    assertEq(blogChallenge.currentDeposit(), 0);
    uint256 depositPart = restDeposit / len;
    for (uint256 j = 0; j < len; j++)
      assertEq(token.balanceOf(participants[j]), part + depositPart);
  }

  function testBalanceNotEnough() public {
    initialize();
    depositPenalty();

    uint256 depositAmount = blogChallenge.depositAmount();

    uint256 len = participants.length;
    uint256 part = penaltyAmount / len; // 一份奖励

    updateCycle(0, true);
    updateCycle(1, true);

    // 清空余额
    uint256 balance = token.balanceOf(challenger);

    vm.prank(challenger);
    token.transfer(address(0x01), balance);

    updateCycle(2, false);

    // 因为提交了博文，这里不会扣费
    assertEq(blogChallenge.currentDeposit(), depositAmount);

    updateCycle(3, true);

    // 没有提交博文，产生扣费，因为余额不足，扣除押金
    uint256 restDeposit = blogChallenge.currentDeposit();
    assertEq(restDeposit, depositAmount - penaltyAmount);
    for (uint256 j = 0; j < len; j++)
      assertEq(token.balanceOf(participants[j]), part);

    updateCycle(4, false); // 第三周期有提交博文，可以继续进行

    // 两次没有提交博文，挑战结束
    // 检查ChallengeEnd
    updateCycle(5, false, false);

    // 直接扣除全部押金
    assertEq(blogChallenge.currentDeposit(), 0);
    uint256 depositPart = restDeposit / len;
    for (uint256 j = 0; j < len; j++)
      assertEq(token.balanceOf(participants[j]), part + depositPart);
  }

  function testParticipate() public {
    address newAddress = address(0x12345);
    address newAddress2 = address(0x12346);

    uint256 joinCycle = 3;

    initialize();
    depositPenalty();

    uint256 curFund = token.balanceOf(challenger);

    require(blogChallenge.isChallengerApproved(), "Challenger not approved");

    for (uint256 i = 0; i <= cycleCnt; i++) {
      updateCycle(i, false);

      if (i == joinCycle) { // 加入
        vm.prank(newAddress);
        vm.expectEmit(true, true, false, false);
        emit Participate(challenger, newAddress);
        blogChallenge.participate();

        // 测试参与人限制
        vm.prank(newAddress2);
        vm.expectRevert("Participants over limit!");
        blogChallenge.participate();
      }

      // 检查是否扣费
      if (i < cycleCnt) // i == cycleCnt 时，押金已经退了，所以不需要再检查了
        require(
          token.balanceOf(challenger) == curFund - penaltyAmount * i,
          toString((1 << 96) +(i << 64) +
        ((curFund - penaltyAmount * i) << 32) +
          token.balanceOf(challenger)
          ));

      // 检查奖励是否平均发放
      uint256 len = participants.length;
      if (i <= joinCycle) {
        uint256 part = penaltyAmount / len; // 一份奖励

        // 检查旧参与者
        for (uint256 j = 0; j < len; j++)
          require(
            token.balanceOf(participants[j]) == part * i,
            toString((2 << 96) + (i << 64) +
          (token.balanceOf(participants[j]) << 32) +
            (part * i)
            ));

      } else { // 后面新地址就加入了
        uint256 part = penaltyAmount / (len + 1); // 一份奖励
        uint256 oldPart = penaltyAmount / len * joinCycle; // 旧的奖励

        // 检查旧参与者
        for (uint256 j = 0; j < len; j++)
          require(
            token.balanceOf(participants[j]) == oldPart + part * (i - joinCycle),
            toString(
              (3 << 96) + (i << 64) +
              (token.balanceOf(participants[j]) << 32) +
              part * (i - joinCycle)
            ));

        // 检查新参与者
        require(
          token.balanceOf(newAddress) == part * (i - joinCycle),
          toString(
            (4 << 96) + (i << 64) +
            (token.balanceOf(newAddress) << 32) +
            part * (i - joinCycle)
          ));
      }
    }

    // 检查是否退回了押金
    assertEq(token.balanceOf(challenger), initFund - penaltyAmount * cycleCnt);
  }

  function testExit() public {
    address exitAddress = address(0x2222);

    uint256 exitCycle = 3;

    initialize();
    depositPenalty();

    uint256 curFund = token.balanceOf(challenger);

    require(blogChallenge.isChallengerApproved(), "Challenger not approved");

    for (uint256 i = 0; i <= cycleCnt; i++) {
      updateCycle(i, false);

      if (i == exitCycle) { // 退出
        vm.prank(exitAddress);
        vm.expectEmit(true, true, false, false);
        emit Exit(challenger, exitAddress);
        blogChallenge.exit();
      }

      // 检查是否扣费
      if (i < cycleCnt) // i == cycleCnt 时，押金已经退了，所以不需要再检查了
        if (i < exitCycle)
          require(
            token.balanceOf(challenger) == curFund - penaltyAmount * i,
            toString((1 << 96) + (i << 64) +
              ((curFund - penaltyAmount * i) << 32) +
              token.balanceOf(challenger)
            ));
        else
          require(
            token.balanceOf(challenger) == curFund - penaltyAmount * i
              + 1 * (i - exitCycle), // 是因为退出一个参与者后出现除以3除不尽的情况，每次都会有1个单位的token没发出去
            toString((1 << 96) + (i << 64) +
              ((curFund - penaltyAmount * i + 1 * (i - exitCycle)) << 32) +
              token.balanceOf(challenger)
            ));


      // 检查奖励是否平均发放
      uint256 len = participants.length;
      if (i <= exitCycle) {
        uint256 part = penaltyAmount / len; // 一份奖励

        // 检查旧参与者
        for (uint256 j = 0; j < len; j++)
          require(
            token.balanceOf(participants[j]) == part * i,
            toString((2 << 96) + (i << 64) +
          (token.balanceOf(participants[j]) << 32) +
            (part * i)
            ));

      } else { // 后面旧地址就退出了
        uint256 part = penaltyAmount / (len - 1); // 一份奖励
        uint256 oldPart = penaltyAmount / len * exitCycle; // 旧的奖励

        // 检查所有参与者（包括退出的那位）
        for (uint256 j = 0; j < len; j++) {
          uint256 targetBalance =
            (participants[j] == exitAddress) ? oldPart :
              (oldPart + part * (i - exitCycle));
          require(
            token.balanceOf(participants[j]) == targetBalance,
            toString(
              (3 << 128) + (i << 96) + (j << 64) +
              (token.balanceOf(participants[j]) << 32) +
              targetBalance
            ));
        }
      }
    }

    // 检查是否退回了押金
    assertEq(token.balanceOf(challenger), initFund - penaltyAmount * cycleCnt
      + 1 * (cycleCnt - exitCycle) // 是因为退出一个参与者后出现除以3除不尽的情况，每次都会有1个单位的token没发出去
    );
  }

  function toString(address account) public pure returns(string memory) {
    return toString(abi.encodePacked(account));
  }
  function toString(uint256 value) public pure returns(string memory) {
    return toString(abi.encodePacked(value));
  }
  function toString(bytes32 value) public pure returns(string memory) {
    return toString(abi.encodePacked(value));
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

}
