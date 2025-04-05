// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "src/BlogChallenge.sol";
import "src/ChallengeFactory.sol";

contract BaseERC20 is ERC20 {
  constructor() ERC20("Base", "Base") {}

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }
}

contract BlogChallengeTest is Test {
  ChallengeFactory factory;
  BlogChallenge blogChallenge;
  BaseERC20 token;

  address challenger = address(0x1111);
  uint256 startTime = 100;
  uint256 cycleDuration = 100;
  uint256 cycleCnt = 12;
  uint256 penaltyAmount = 30 ether;
  uint256 initFund = 1000000 ether;
  uint256 maxParticipants = 3;
  bool freeMode = false;
  bool participatable = true;

  address[] whitelist;
  address[] participants;

  event ChallengeStart(address indexed challenger);
  event ChallengeEnd(address indexed challenger, bool indexed passed);
  event SubmitBlog(
    address indexed challenger, 
    uint256 indexed cycle, 
    string title,
    string description,
    string url
  );
  event CycleEnd(address indexed challenger, uint256 indexed cycle, bool indexed passed);
  event Participate(address indexed challenger, address indexed participant, uint256 amount);
  event Release(address indexed challenger, uint256 indexed cycle, uint256 amount);

  function setUp() public {
    // 设置地址
    participants = new address[](maxParticipants * 2);
    whitelist = new address[](maxParticipants);

    for (uint256 i = 0; i < maxParticipants; i++) {
      participants[i] = address(uint160(0x2222 + i));
      participants[i + maxParticipants] = address(uint160(0x2222 + i + maxParticipants));
      whitelist[i] = address(uint160(0x2222 + i));
    }

    token = new BaseERC20();
    factory = new ChallengeFactory();

    // 初始资金
    token.mint(challenger, initFund);
    for (uint256 i = 0; i < maxParticipants * 2; i++) {
      token.mint(participants[i], initFund);
    }

    vm.startPrank(challenger);

    // 创建挑战实例
    address challengeAddr = factory.createChallenge(
      startTime,
      cycleDuration,
      cycleCnt,
      address(token),
      penaltyAmount,
      maxParticipants,
      freeMode,
      participatable
    );
    blogChallenge = BlogChallenge(challengeAddr);
    blogChallenge.setParticipatable(true);

    token.approve(address(blogChallenge), blogChallenge.approveAmount());
    blogChallenge.depositPenalty();

    // 验证代币名称和符号（使用challenges.length作为id）
    assertEq(blogChallenge.name(), "Blog Challenge Token #1");
    assertEq(blogChallenge.symbol(), "BLOG#1");
    assertEq(blogChallenge.id(), 1);

    vm.stopPrank();
  }

  function testChallengeSuccess() public {
    // 参与者参与挑战
    uint256 shareBps = 5000;
    uint256 sumCost = 0;
    uint256[] memory costs = new uint256[](maxParticipants);

    for (uint256 i = 0; i < maxParticipants; i++) {
      vm.startPrank(participants[i]);

      costs[i] = blogChallenge.participateCost(shareBps);
      token.approve(address(blogChallenge), costs[i]);
      blogChallenge.participate(shareBps);

      vm.stopPrank();

      sumCost += costs[i];
    }

    vm.startPrank(challenger);

    // 提交博客
    for(uint256 i = 0; i < cycleCnt; i++) {
      vm.warp(startTime + (i * cycleDuration) + 1);
      blogChallenge.submitBlog("Test Blog", "Test Description", "https://test.com");
    }

    // 跳到挑战结束时间
    vm.warp(startTime + ((cycleCnt + 1) * cycleDuration));

    // 更新所有周期
    vm.expectEmit(true, false, false, true);
    emit ChallengeEnd(challenger, true);

    blogChallenge.updateCycle();

    vm.stopPrank();

    // 检查挑战是否成功
    assertTrue(blogChallenge.checkSuccess());

    // 检查余额变化
    assertEq(token.balanceOf(address(blogChallenge)), 0);
    // 挑战者应该能取回全部押金，并获得参与者的收入
    assertEq(token.balanceOf(challenger), initFund + sumCost);
    // 参与者的押金应该被扣除
    for (uint256 i = 0; i < maxParticipants; i++) {
      assertEq(token.balanceOf(participants[i]), initFund - costs[i]);
    }
  }

  function testMultipleChallenges() public {
    vm.startPrank(challenger);

    // 创建第二个挑战
    address challenge2Addr = factory.createChallenge(
      startTime,
      cycleDuration,
      cycleCnt,
      address(token),
      penaltyAmount,
      0, // no limit
      freeMode,
      participatable
    );
    BlogChallenge challenge2 = BlogChallenge(challenge2Addr);
    
    // 验证第二个挑战的id和代币信息
    assertEq(challenge2.name(), "Blog Challenge Token #2");
    assertEq(challenge2.symbol(), "BLOG#2");
    assertEq(challenge2.id(), 2);

    token.approve(address(challenge2), challenge2.approveAmount());
    challenge2.depositPenalty();

    vm.stopPrank();

    // 参与者参与挑战
    uint256 shareBps = 5000;
    uint256 sumCost = 0;
    uint256[] memory costs = new uint256[](participants.length);

    for (uint256 i = 0; i < participants.length; i++) {
      vm.startPrank(participants[i]);

      costs[i] = challenge2.participateCost(shareBps);
      token.approve(address(challenge2), costs[i]);
      challenge2.participate(shareBps);

      vm.stopPrank();

      sumCost += costs[i];
    }

    assertEq(token.balanceOf(address(challenge2)), challenge2.depositAmount() + sumCost);

    for (uint256 i = 0; i < participants.length; i++) {
      assertEq(token.balanceOf(participants[i]), initFund - costs[i]);
      assertEq(challenge2.participants(i), participants[i]);
    }
  }

  function testWhitelistParticipation() public {
    uint256 shareBps = 5000;
    address participant = participants[maxParticipants];
    
    // 先不设置白名单，应该可以参与
    vm.startPrank(participant);

    uint256 cost1 = blogChallenge.participateCost(shareBps);
    token.approve(address(blogChallenge), cost1);
    blogChallenge.participate(shareBps);
    
    vm.stopPrank();

    // 设置白名单
    vm.prank(challenger);
    
    blogChallenge.setWhitelist(whitelist);

    // 白名单内地址可以参与
    address whitelistedUser = whitelist[0];
    vm.startPrank(whitelistedUser);

    uint256 cost2 = blogChallenge.participateCost(shareBps);
    token.approve(address(blogChallenge), cost2);
    blogChallenge.participate(shareBps);

    vm.stopPrank();
    
    // 非白名单地址不能参与
    address nonWhitelistedUser = participants[maxParticipants + 1];
    vm.startPrank(nonWhitelistedUser);

    uint256 cost3 = blogChallenge.participateCost(shareBps);
    token.approve(address(blogChallenge), cost3);
    vm.expectRevert("Not in whitelist");
    blogChallenge.participate(shareBps);

    vm.stopPrank();
  }

  function testMaxParticipants() public {
    uint256 shareBps = 5000;

    for (uint256 i = 0; i < maxParticipants; i++) {
      vm.startPrank(participants[i]);

      uint256 _cost = blogChallenge.participateCost(shareBps);
      token.approve(address(blogChallenge), _cost);
      blogChallenge.participate(shareBps);

      vm.stopPrank();
    }

    // 尝试添加超出限制的参与者
    address extraParticipant = participants[maxParticipants];
    uint256 cost = blogChallenge.participateCost(shareBps);

    vm.startPrank(extraParticipant);

    token.approve(address(blogChallenge), cost);
    vm.expectRevert("Participants over limit");
    blogChallenge.participate(shareBps);

    vm.stopPrank();
  }

  function testParticipantManagement() public {
    uint256 shareBps = 5000;

    address participant1 = participants[0];
    address participant2 = participants[1];
    
    // 参与者1加入
    vm.startPrank(participant1);
    
    uint256 cost = blogChallenge.participateCost(shareBps);
    uint256 expectAmount = blogChallenge.minShareBps2Amount(shareBps);

    token.approve(address(blogChallenge), cost);
    blogChallenge.participate(shareBps);

    vm.stopPrank();

    // 验证参与者列表更新
    assertEq(blogChallenge.participants(0), participant1);

    uint256 amount = blogChallenge.balanceOf(participant1);
    assertEq(amount, expectAmount);
    
    // 参与者1转移全部代币给参与者2
    vm.startPrank(participant1);
    blogChallenge.transfer(participant2, amount);
    vm.stopPrank();
    
    // 验证参与者列表更新
    assertEq(blogChallenge.participants(0), participant2);

    assertEq(blogChallenge.balanceOf(participant1), 0);
    assertEq(blogChallenge.balanceOf(participant2), amount);
  }

  function testSubmitBlog() public {
    vm.startPrank(challenger);
    
    string memory title = "Test Blog";
    string memory description = "Test Description";
    string memory url = "https://test.com";
    
    vm.expectEmit(true, true, false, true);
    emit SubmitBlog(challenger, blogChallenge.currentCycle(), title, description, url);
    
    blogChallenge.submitBlog(title, description, url);
    
    vm.stopPrank();
  }

  function testRewardDistribution() public {
    address participant1 = participants[0];
    address participant2 = participants[1];
    
    // 设置不同数量的代币持有
    uint256 amount1 = 100 ether;
    uint256 amount2 = 200 ether;
    
    // 参与者1参与
    vm.startPrank(participant1);

    uint256 cost1 = blogChallenge.participateWithAmountCost(amount1);
    token.approve(address(blogChallenge), cost1);
    blogChallenge.participateWithAmount(amount1);

    vm.stopPrank();
    
    // 参与者2参与
    vm.startPrank(participant2);

    uint256 cost2 = blogChallenge.participateWithAmountCost(amount2);
    token.approve(address(blogChallenge), cost2);
    blogChallenge.participateWithAmount(amount2);

    vm.stopPrank();

    assertEq(blogChallenge.participants(0), participant1);
    assertEq(blogChallenge.participants(1), participant2);
    
    // 挑战者错过一个周期
    vm.warp(startTime + cycleDuration + 1);
    
    // 更新周期触发奖励分发
    blogChallenge.updateCycle();
    
    // 验证奖励按比例分配
    uint256 reward1 = token.balanceOf(participant1) - initFund;
    uint256 reward2 = token.balanceOf(participant2) - initFund;

    assertEq(reward2, reward1 * 2);
  }

  function testPermissions() public {
    address nonChallenger = participants[0];
    
    vm.startPrank(nonChallenger);
    
    // 非挑战者尝试存入押金
    token.approve(address(blogChallenge), blogChallenge.approveAmount());
    vm.expectRevert("Not challenger!");
    blogChallenge.depositPenalty();

    // 非挑战者尝试启用参与
    vm.expectRevert("Not challenger!");
    blogChallenge.setParticipatable(true);

    // 非挑战者尝试提交博客
    vm.warp(startTime + 1);
    vm.expectRevert("Not challenger!");
    blogChallenge.submitBlog("Test Blog", "Test Description", "https://test.com");

    vm.stopPrank();
  }

  // function testChallengeFail() public {
  //   // 参与者参与挑战
  //   uint256 shareBps = 5000;
  //   uint256 sumCost = 0;
  //   uint256[] memory costs = new uint256[](maxParticipants);

  //   for (uint256 i = 0; i < maxParticipants; i++) {
  //     vm.startPrank(participants[i]);

  //     costs[i] = blogChallenge.participateCost(shareBps);
  //     token.approve(address(blogChallenge), costs[i]);
  //     blogChallenge.participate(shareBps);

  //     vm.stopPrank();

  //     sumCost += costs[i];
  //   }

  //   vm.startPrank(challenger);
    
  //   // 只提交一半的博客
  //   uint256 halfCycles = cycleCnt / 2;
  //   for(uint256 i = 0; i < halfCycles; i++) {
  //     vm.warp(startTime + (i * cycleDuration) + 1);
  //     blogChallenge.submitBlog("Test Blog", "Test Description", "https://test.com");
  //   }
    
  //   // 跳到挑战结束时间
  //   vm.warp(startTime + ((cycleCnt + 1) * cycleDuration));
    
  //   // 更新所有周期
  //   vm.expectEmit(true, false, false, true);
  //   emit ChallengeEnd(challenger, false);
    
  //   blogChallenge.updateCycle();
    
  //   vm.stopPrank();

  //   // 检查挑战是否失败
  //   assertFalse(blogChallenge.checkSuccess());

  //   // 检查余额变化
  //   assertEq(token.balanceOf(address(blogChallenge)), 0);
  //   // 挑战者应该损失押金
  //   assertEq(token.balanceOf(challenger), initFund - blogChallenge.depositAmount());
  //   // 参与者应该按比例分得押金
  //   uint256 depositAmount = blogChallenge.depositAmount();
  //   for (uint256 i = 0; i < maxParticipants; i++) {
  //     uint256 share = depositAmount * blogChallenge.balanceOf(participants[i]) / blogChallenge.totalSupply();
  //     assertEq(token.balanceOf(participants[i]), initFund - costs[i] + share);
  //   }
  // }

  // function testTimeConstraints() public {
  //   vm.startPrank(challenger);

  //   // 尝试在开始时间前提交博客
  //   vm.warp(startTime - 1);
  //   vm.expectRevert("Not started");
  //   blogChallenge.submitBlog("Test Blog", "Test Description", "https://test.com");

  //   // 尝试在周期结束后提交博客
  //   vm.warp(startTime + cycleDuration + 1);
  //   blogChallenge.submitBlog("Test Blog 1", "Test Description", "https://test.com");
  //   vm.warp(startTime + cycleDuration + cycleDuration);
  //   blogChallenge.submitBlog("Test Blog 2", "Test Description", "https://test.com");

  //   // 尝试在挑战结束后提交博客
  //   vm.warp(startTime + ((cycleCnt + 2) * cycleDuration));
  //   vm.expectRevert("Not ended");
  //   blogChallenge.submitBlog("Test Blog 3", "Test Description", "https://test.com");

  //   vm.stopPrank();
  // }

  // function testParticipationConstraints() public {

  //   address participant = participants[0];
  //   vm.startPrank(participant);

  //   // 在未启用参与时尝试参与
  //   uint256 shareBps = 5000;
  //   uint256 cost = blogChallenge.participateCost(shareBps);
  //   token.approve(address(blogChallenge), cost);
  //   vm.expectRevert("Participation not enabled");
  //   blogChallenge.participate(shareBps);

  //   vm.stopPrank();
  //   vm.startPrank(challenger);
  //   blogChallenge.setEnableParticipate(true);
  //   vm.stopPrank();
  //   vm.startPrank(participant);

  //   // 测试最小份额限制
  //   vm.expectRevert("Cost too small");
  //   blogChallenge.participate(100); // 1%

  //   // 正常参与
  //   token.approve(address(blogChallenge), cost);
  //   blogChallenge.participate(shareBps);

  //   // 测试重复参与
  //   uint256 cost2 = blogChallenge.participateCost(shareBps);
  //   token.approve(address(blogChallenge), cost2);
  //   blogChallenge.participate(shareBps);

  //   // 验证余额增加了
  //   assertGt(blogChallenge.balanceOf(participant), blogChallenge.minShareBps2Amount(shareBps));

  //   vm.stopPrank();

  //   // 跳到挑战结束后
  //   vm.startPrank(challenger);
  //   vm.warp(startTime + ((cycleCnt + 1) * cycleDuration));
  //   blogChallenge.updateCycle();
  //   vm.stopPrank();

  //   // 尝试在挑战结束后参与
  //   vm.startPrank(participants[1]);
  //   uint256 cost3 = blogChallenge.participateCost(shareBps);
  //   token.approve(address(blogChallenge), cost3);
  //   vm.expectRevert("Not started");
  //   blogChallenge.participate(shareBps);
  //   vm.stopPrank();
  // }

  // function testCycleUpdates() public {
  //   vm.startPrank(challenger);

  //   // 提交第一个周期的博客
  //   vm.warp(startTime + 1);
  //   blogChallenge.submitBlog("Blog 1", "Description 1", "https://test.com/1");
    
  //   // 跳过一个周期
  //   vm.warp(startTime + (3 * cycleDuration));
  //   blogChallenge.submitBlog("Blog 3", "Description 3", "https://test.com/3");
    
  //   // 更新周期
  //   blogChallenge.updateCycle();
    
  //   // 验证跳过的周期被标记为未完成
  //   assertFalse(blogChallenge.isCycleSucceed(2));
  //   assertTrue(blogChallenge.isCycleSucceed(1));
  //   assertTrue(blogChallenge.isCycleSucceed(3));

  //   vm.stopPrank();
  // }
}
