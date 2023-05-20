// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BlogChallenge {
  // 挑战的数据结构
  struct Challenge {
    uint256 startTime; // 挑战开始时间（s）
    uint256 cycle; // 挑战周期长度
    uint256 numberOfCycles; // 周期数

    address challenger; // 挑战者地址
    address[] participants; // 参与者地址

    IERC20 penaltyToken; // 惩罚币种
    uint256 penaltyAmount; // 惩罚金额

    uint256 deposit; // 押金（已存入的押金）
    string[][] blogSubmissions; // 博客提交情况
    uint8 noBalanceCount; // 余额不足次数

    uint256 lastUpdatedCycle; // 最后更新的Cycle
    bool started; // 挑战是否开始
  }

  // 当前挑战
  Challenge public currentChallenge;

  uint256 public constant DEPOSIT_MULTIPLIER = 3; // 押金倍数
  uint256 public constant SUCCEED_RATE = 60; // 挑战成功所需的比率

  // region modifier

  modifier onlyChallenger() {
    require(msg.sender == currentChallenge.challenger, "Not challenger!");
    _;
  }
  modifier onlyParticipant() {
    bool isParticipant = false;
    for (uint256 i = 0; i < currentChallenge.participants.length; i++) {
      if (msg.sender == currentChallenge.participants[i]) {
        isParticipant = true;
        break;
      }
    }
    require(isParticipant, "Not participant!");
    _;
  }
  modifier onlyNotParticipant() {
    bool isParticipant = false;
    for (uint256 i = 0; i < currentChallenge.participants.length; i++) {
      if (msg.sender == currentChallenge.participants[i]) {
        isParticipant = true;
        break;
      }
    }
    require(msg.sender != currentChallenge.challenger && !isParticipant, "Already participant!");
    _;
  }
  modifier onlyStarted() {
    require(currentChallenge.started, "Not started");
    _;
  }
  modifier onlyEnded() {
    require(!currentChallenge.started, "Not ended");
    _;
  }
  modifier onlyAfter(uint256 time) {
    require(block.timestamp >= time, "Function called too early");
    _;
  }
  modifier onlyBefore(uint256 time) {
    if (time > 0)
      require(block.timestamp < time, "Function called too late");
    _;
  }

  // endregion

  // region View calls

  // 当前周期数（0表示没有开始，从1开始，最大值为currentChallenge.numberOfCycles + 1）
  function currentCycle() public onlyStarted view returns (uint256) {
    if (block.timestamp < currentChallenge.startTime) return 0;

    uint256 res = (block.timestamp - currentChallenge.startTime) / currentChallenge.cycle + 1;
    if (res > currentChallenge.numberOfCycles) return currentChallenge.numberOfCycles + 1;

    return res;
  }
  function currentCycleIdx() public view returns (uint256) {
    return currentCycle() - 1;
  }

  // 是否最后一个周期
  function isLastCycle(uint256 cycle) public onlyStarted view returns (bool) {
    return cycle >= currentChallenge.numberOfCycles;
  }
  // 是否最后一个周期也已经完成
  function isFinishedCycle(uint256 cycle) public onlyStarted view returns (bool) {
    return cycle >= currentChallenge.numberOfCycles + 1;
  }

  // 是否将要被更新的周期
  function isToBeUpdatedCycle(uint256 cycle) public view returns (bool) {
    // 周期必须在当前周期之前，上一个已经更新过的周期之后
    return cycle < currentCycle() && cycle > currentChallenge.lastUpdatedCycle;
  }

  // 周期是否成功（周期都是从1开始的）
  function isCycleSucceed(uint256 cycle) public onlyStarted view returns (bool) {
    return currentChallenge.blogSubmissions[cycle - 1].length > 0;
  }

  // 检查挑战是否成功
  function checkSuccess() public onlyStarted view returns (bool) {
    // 成功提交的次数
    uint256 successfulSubmissions = 0;
    // 遍历所有周期
    for (uint256 i = 1; i <= currentChallenge.numberOfCycles; i++)
    // 如果该周期提交了博客，成功次数加一
      if (isCycleSucceed(i)) successfulSubmissions++;

    // 如果成功次数达到总周期数的60%，则挑战成功
    return successfulSubmissions >= currentChallenge.numberOfCycles * SUCCEED_RATE / 100;
  }

  // 获取要授权的代币数量
  function approveAmount() public onlyStarted view returns (uint256) {
    return currentChallenge.penaltyAmount * (DEPOSIT_MULTIPLIER + currentChallenge.numberOfCycles);
  }

  // 挑战者是否授权
  function isChallengerApproved() public onlyStarted view returns (bool) {
    IERC20 token = currentChallenge.penaltyToken;
    uint256 approve = token.allowance(currentChallenge.challenger, address(this));
    return approve >= approveAmount();
  }

  // endregion

  // region Public calls

  // 设置挑战
  function setChallenge(
    uint256 _startTime,
    uint256 _cycle,
    uint256 _numberOfCycles,
    address _challenger,
    address[] memory _participants,
    IERC20 _penaltyToken,
    uint256 _penaltyAmount
  ) public onlyEnded {

    string[][] memory blogSubmissions = new string[][](_numberOfCycles);
    for (uint256 i = 0; i < _numberOfCycles; i++)
      blogSubmissions[i] = new string[](0);

    // 初始化当前挑战
    currentChallenge = Challenge({
    // 时间设置
    startTime: _startTime,
    cycle: _cycle,
    numberOfCycles: _numberOfCycles,

    // 人员设置
    challenger: _challenger,
    participants: _participants,

    // 惩罚设置
    penaltyToken: _penaltyToken,
    penaltyAmount: _penaltyAmount,

    // 挑战者状态
    deposit: 0,
    blogSubmissions: blogSubmissions,
    noBalanceCount: 0,

    // 挑战状态
    lastUpdatedCycle: 0,
    started: true
    });
  }

  // 中途加入
  function participate() public onlyNotParticipant onlyStarted {
    currentChallenge.participants.push(msg.sender);
  }

  // 更新周期（任何人都能调用）
  function updateCycle() public onlyStarted {
    uint256 cycle = currentChallenge.lastUpdatedCycle + 1;
    require(isToBeUpdatedCycle(cycle), "All cycles are updated!");

    do {
      string[] memory blogs = currentChallenge.blogSubmissions[cycle - 1];

      // 如果挑战者没有提交博客，则发放惩罚金
      if (blogs.length <= 0) onCycleFailed();
      // 否则视为通过
      else onCyclePass();

      cycle++;
    } while (currentChallenge.started && isToBeUpdatedCycle(cycle));

    // 更新lastUpdatedCycle
    currentChallenge.lastUpdatedCycle = cycle - 1;

    if (currentChallenge.started && isFinishedCycle(cycle))
      endChallenge(checkSuccess());
  }

  // endregion

  // region Challenger calls

  // 存入押金
  function depositPenalty() public onlyChallenger onlyStarted {
    uint256 deposit = currentChallenge.penaltyAmount * DEPOSIT_MULTIPLIER;

    require(currentChallenge.deposit < deposit, "Have been deposited!");

    currentChallenge.penaltyToken.transferFrom(msg.sender, address(this), deposit);
    currentChallenge.deposit = deposit;
  }

  // 提交博客
  function submitBlog(string memory blogUrl) public onlyChallenger onlyStarted {
    // 记录博客提交情况
    currentChallenge.blogSubmissions[currentCycleIdx()].push(blogUrl);
  }

  // 提取押金
  function withdrawDeposit() public onlyChallenger onlyStarted {
    // 将剩余押金转给挑战者
    currentChallenge.penaltyToken.transfer(msg.sender, currentChallenge.deposit);
  }

  // endregion

  // region Participant calls

  // 中途退出
  function exit() public onlyEnded {
    uint256 len = currentChallenge.participants.length;
    for (uint256 i = 0; i < len; i++) {
      if (msg.sender == currentChallenge.participants[i]) {
        currentChallenge.participants[i] = currentChallenge.participants[len - 1];
        currentChallenge.participants.pop();
        break;
      }
    }
  }

  // endregion

  // region Private calls

  // 给参与者发放奖励
  function releaseToParticipants(address payer, uint256 totalAmount) private {
    IERC20 token = currentChallenge.penaltyToken;
    uint256 length = currentChallenge.participants.length;
    uint256 amount = totalAmount / length;

    for (uint256 i; i < length; i++) {
      address participant = currentChallenge.participants[i];
      if (payer == address(this)) // 如果payer是合约，直接发起转账
        token.transfer(participant, amount);
      else // 否则通过授权转账
        token.transferFrom(payer, participant, amount);
    }
  }

  // 周期成功回调
  function onCyclePass() private {
  }
  // 周期失败回调
  function onCycleFailed() private {
    IERC20 token = currentChallenge.penaltyToken;
    uint256 balance = token.balanceOf(currentChallenge.challenger);
    uint256 amount = currentChallenge.penaltyAmount;

    if (balance < amount || !isChallengerApproved()) { // 如果余额或授权数量不足
      currentChallenge.noBalanceCount++;

      // 如果两次余额不足
      if (currentChallenge.noBalanceCount >= 2) {
        // 将剩余押金平均分给参与者
        releaseToParticipants(address(this), currentChallenge.deposit);
        currentChallenge.deposit = 0;
        endChallenge(false);
      }

      // 如果有足够的押金
      else if (currentChallenge.deposit >= amount) {
        // 扣除并释放惩罚金（通过押金的方式）
        releaseToParticipants(address(this), amount);
        currentChallenge.deposit -= amount;
      }

      // 否则结束挑战
      else endChallenge(false);
    }
    // 如果余额和授权充足，扣除并释放惩罚金
    else releaseToParticipants(currentChallenge.challenger, amount);
  }

  // 结束挑战
  function endChallenge(bool success) private {
    // 挑战成功
    if (success) onChallengePass();
    // 挑战失败
    else onChallengeFailed();

    // 标记挑战为已结束
    currentChallenge.started = false;
  }
  // 挑战成功回调
  function onChallengePass() private {
    // TODO: 发放NFT
  }
  // 挑战失败回调
  function onChallengeFailed() private {
  }

  // endregion
}
