// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BlogChallenge is ERC20, ReentrancyGuard {
  // Token相关状态
  uint256 public constant INITIAL_SUPPLY = 1_000_000 ether; // 1M tokens
  uint256 public constant TOKEN_PRICE_MULTIPLIER = 200; // 200% penaltyAmount / 10M token

  uint256 public constant DEPOSIT_MULTIPLIER = 3; // 押金倍数
  uint256 public constant SUCCEED_RATE = 60; // 挑战成功所需的比率

  uint256 public constant MIN_PARTICIPATE_TOKEN_AMOUNT = 100 ether; // 最小购买代币数量

  uint256 public id;
  address public factory;

  uint256 public startTime; // 挑战开始时间（s）
  uint256 public cycle; // 挑战周期长度
  uint256 public numberOfCycles; // 周期数

  address public challenger; // 挑战者地址
  address[] public participants; // 参与者地址
  address[] public whitelist; // 白名单地址

  IERC20 public penaltyToken; // 惩罚币种
  uint256 public penaltyAmount; // 惩罚金额

  uint256 public maxParticipants; // 最大参与人数
  bool public freeMode; // 免费模式

  uint256 public deposit; // 押金（已存入的押金）

  struct BlogSubmission {
    uint256 cycle;
    string title;
    string description;
    string url;
    uint256 timestamp;
  }

  BlogSubmission[] public blogSubmissions; // 博客提交情况
  uint8 public noBalanceCount; // 余额不足次数

  uint256 public lastUpdatedCycle; // 最后更新的Cycle

  bool public started; // 挑战是否开始
  bool public participatable; // 是否可以参与

  // region events

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
  
  // endregion

  // region modifier

  modifier onlyChallenger() {
    require(msg.sender == challenger, "Not challenger!");
    _;
  }
  modifier onlyParticipant() {
    bool isParticipant = false;
    for (uint256 i = 0; i < participants.length; i++) {
      if (msg.sender == participants[i]) {
        isParticipant = true;
        break;
      }
    }
    require(isParticipant, "Not participant!");
    _;
  }
  modifier onlyNotParticipant() {
    bool isParticipant = false;
    for (uint256 i = 0; i < participants.length; i++) {
      if (msg.sender == participants[i]) {
        isParticipant = true;
        break;
      }
    }
    require(msg.sender != challenger && !isParticipant, "Already participant!");
    _;
  }
  modifier onlyStarted() {
    require(started, "Not started");
    _;
  }
  modifier onlyEnded() {
    require(!started, "Not ended");
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
  modifier onlyWhitelisted() {
    if (whitelist.length > 0) {
      bool isWhitelisted = false;
      for (uint256 i = 0; i < whitelist.length; i++) {
        if (msg.sender == whitelist[i]) {
          isWhitelisted = true;
          break;
        }
      }
      require(isWhitelisted, "Not in whitelist");
    }
    _;
  }
  modifier checkParticipantLimit() {
    require(participatable, "Not participatable");

    if (maxParticipants > 0) require(participants.length < maxParticipants, "Participants over limit");

    _;
  }

  // endregion

//  constructor() ERC20("Blog Challenge Token", "BLOG") public {
//    factory = msg.sender;
//  }
  constructor(
    uint256 _id,
    address _challenger,
    uint256 _startTime,
    uint256 _cycle,
    uint256 _numberOfCycles,
    address _penaltyToken,
    uint256 _penaltyAmount,
    uint256 _maxParticipants,
    bool _freeMode,
    bool _participatable
  ) ERC20(
    string.concat("Blog Challenge Token #", Strings.toString(_id)),
    string.concat("BLOG#", Strings.toString(_id))
  ) {
    factory = msg.sender;

    id = _id;
    challenger = _challenger;
    startTime = _startTime;
    cycle = _cycle;
    numberOfCycles = _numberOfCycles;
    penaltyToken = IERC20(_penaltyToken);
    penaltyAmount = _penaltyAmount;
    maxParticipants = _maxParticipants;
    freeMode = _freeMode;
    participatable = _participatable;

    started = true;

    // 铸造挑战代币
    _mint(address(this), INITIAL_SUPPLY);

    emit ChallengeStart(_challenger);
  }

  // region View calls

  function getInfo() public view returns (uint256, address, uint256, uint256, uint256, address, uint256, uint256, bool) {
    return (id, challenger, startTime, cycle, numberOfCycles, address(penaltyToken), penaltyAmount, maxParticipants, freeMode);
  }
  function getState() public view returns (uint256, uint256, bool, bool, uint256, uint256, uint256, bool) {
    return (currentCycle(), lastUpdatedCycle, started, participatable, participants.length, blogSubmissions.length, deposit, isChallengerApproved());
  }

  // 当前周期数（0表示没有开始，从1开始，最大值为numberOfCycles + 1）
  function currentCycle() public view returns (uint256) {
    if (block.timestamp < startTime) return 0;

    uint256 res = (block.timestamp - startTime) / cycle + 1;
    if (res > numberOfCycles) return numberOfCycles + 1;

    return res;
  }
  function currentCycleIdx() public view returns (uint256) {
    uint256 _cycle = currentCycle();
    return _cycle <= 0 ? 0 : _cycle - 1;
  }

  // 是否最后一个周期
  function isLastCycle(uint256 _cycle) public view returns (bool) {
    return _cycle >= numberOfCycles;
  }
  // 是否最后一个周期也已经完成
  function isFinishedCycle(uint256 _cycle) public view returns (bool) {
    return _cycle >= numberOfCycles + 1;
  }

  // 是否将要被更新的周期
  function isToBeUpdatedCycle(uint256 _cycle) public view returns (bool) {
    // 周期必须在当前周期之前，上一个已经更新过的周期之后
    return _cycle < currentCycle() && _cycle > lastUpdatedCycle;
  }

  // 周期是否成功（周期都是从1开始的）
  function isCycleSucceed(uint256 _cycle) public view returns (bool) {
    for (uint256 i = 0; i < blogSubmissions.length; i++) {
      if (blogSubmissions[i].cycle == _cycle) return true;
    }
    return false;
  }

  // 检查挑战是否成功
  function checkSuccess() public view returns (bool) {
    // 成功提交的次数
    uint256 successfulSubmissions = 0;
    // 遍历所有周期
    for (uint256 i = 1; i <= numberOfCycles; i++)
    // 如果该周期提交了博客，成功次数加一
      if (isCycleSucceed(i)) successfulSubmissions++;

    // 如果成功次数达到总周期数的60%，则挑战成功
    return successfulSubmissions >= numberOfCycles * SUCCEED_RATE / 100;
  }

  // 获取要授权的代币数量
  function approveAmount() public view returns (uint256) {
    return penaltyAmount * (DEPOSIT_MULTIPLIER + numberOfCycles);
  }
  // 获取押金的代币数量
  function depositAmount() public view returns (uint256) {
    return penaltyAmount * DEPOSIT_MULTIPLIER;
  }

  // 挑战者是否授权
  function isChallengerApproved() public view returns (bool) {
    IERC20 token = penaltyToken;
    uint256 approve = token.allowance(challenger, address(this));

    if (deposit <= 0) // 未交押金
      return approve >= approveAmount();

    uint256 restCycle = numberOfCycles - currentCycleIdx();
    return approve >= penaltyAmount * restCycle;
  }

  // 获取当前能购买的最大持股比例
  function maxShareBps(address user) public view returns (uint256) {
    if (freeMode) return 10000 / (participants.length + 1);

    uint256 restTokens = balanceOf(address(this));
    uint256 userBalance = balanceOf(user);

    // 计算最大持股比例
    uint256 maxUserBalance = restTokens + userBalance;
    return maxUserBalance * 10000 / totalSupply();
  }

  function minShareBps2Amount(uint256 minShareBps) public view returns (uint256) {
    if (freeMode) return MIN_PARTICIPATE_TOKEN_AMOUNT;

    uint256 restTokens = balanceOf(address(this));
    uint256 soldTokens = totalSupply() - restTokens;
    uint256 userBalance = balanceOf(msg.sender);

    if (minShareBps >= 10000) return totalSupply(); // 100%

    uint256 tokenAmount = (minShareBps * soldTokens - 10000 * userBalance) / (10000 - minShareBps);
    if (tokenAmount < MIN_PARTICIPATE_TOKEN_AMOUNT) tokenAmount = MIN_PARTICIPATE_TOKEN_AMOUNT;

    return tokenAmount;

//    return (minShareBps * soldTokens - 10000 * userBalance) / (10000 - minShareBps);
  }

  function participateCost(uint256 minShareBps) public view returns (uint256) {
    return participateWithAmountCost(minShareBps2Amount(minShareBps));
  }

  function participateWithAmountCost(uint256 tokenAmount) public view returns (uint256) {
    if (freeMode) return 0;

    if (tokenAmount < MIN_PARTICIPATE_TOKEN_AMOUNT) tokenAmount = MIN_PARTICIPATE_TOKEN_AMOUNT;

    return (tokenAmount * penaltyAmount * 100) / (TOKEN_PRICE_MULTIPLIER * INITIAL_SUPPLY);
  }

  // endregion

  // region Public calls

  // 中途加入
  function participate(uint256 minShareBps) public 
    nonReentrant 
    onlyStarted 
    onlyWhitelisted 
    checkParticipantLimit 
  {
    _participateWithAmount(minShareBps2Amount(minShareBps));
  }

  // 中途加入（指定代币数量）
  function participateWithAmount(uint256 tokenAmount) public 
    nonReentrant 
    onlyStarted 
    onlyWhitelisted 
    checkParticipantLimit 
  {
    _participateWithAmount(tokenAmount);
  }

  function _participateWithAmount(uint256 tokenAmount) internal {
    if (freeMode) require(balanceOf(msg.sender) == 0, "Already participated");

    if (freeMode || tokenAmount < MIN_PARTICIPATE_TOKEN_AMOUNT) tokenAmount = MIN_PARTICIPATE_TOKEN_AMOUNT;

    require(tokenAmount <= balanceOf(address(this)), "Not enough tokens");

    uint256 cost = participateWithAmountCost(tokenAmount); // (tokenAmount * penaltyAmount * 100) / (TOKEN_PRICE_MULTIPLIER * INITIAL_SUPPLY);

    // 转移惩罚代币
    if (cost > 0) 
      require(
        penaltyToken.transferFrom(msg.sender, address(this), cost),
        "Transfer failed"
      );

    // 转移挑战代币
    _transfer(address(this), msg.sender, tokenAmount);

//    if (userBalance <= 0) participants.push(msg.sender);

    emit Participate(challenger, msg.sender, tokenAmount);
  }

  // 更新周期（任何人都能调用）
  function updateCycle() public onlyStarted {
    uint256 _cycle = lastUpdatedCycle + 1;
    require(isToBeUpdatedCycle(_cycle), "All cycles are updated!");

    do {
      bool isSucceed = isCycleSucceed(_cycle);

      // 如果挑战者没有提交博客，则发放惩罚金
      if (!isSucceed) onCycleFailed();
      // 否则视为通过
      else onCyclePass();

      emit CycleEnd(challenger, _cycle, isSucceed);

      _cycle++;
    } while (started && isToBeUpdatedCycle(_cycle));

    // 更新lastUpdatedCycle
    lastUpdatedCycle = _cycle - 1;

    if (started && isFinishedCycle(_cycle))
      endChallenge(checkSuccess());
  }

  // endregion

  // region ERC20 Override

  function _update(
    address from,
    address to,
    uint256 amount
  ) internal override {
    super._update(from, to, amount);

    require(to != challenger, "Cannot send token to blog challenger");

    // Skip checks for minting and burning
    if (from == address(0) || to == address(0)) return;

    // Check if this transfer would create a new participant
    bool isNewParticipant = balanceOf(to) == amount && to != address(this);
    
    if (isNewParticipant) {
      // Check participant limit
      if (maxParticipants > 0) {
        require(participants.length < maxParticipants, "Transfer would exceed participant limit");
      }
      
      // Add new participant
      participants.push(to);
    }

    // Remove sender from participants if they're transferring their entire balance
    if (from != address(this) && balanceOf(from) == 0) {
      for (uint256 i = 0; i < participants.length; i++) {
        if (participants[i] == from) {
          participants[i] = participants[participants.length - 1];
          participants.pop();
          break;
        }
      }
    }
  }

  // endregion

  // region Challenger calls

  // 赠送代币（只有挑战者可以调用）
  function transferTokens(address to, uint256 amount) external onlyChallenger {
    // require(amount > 0, "Amount must be greater than 0");
    // require(balanceOf(address(this)) >= amount, "Not enough available tokens");
    _transfer(address(this), to, amount);
  }

  // 设置是否可以参与
  function setParticipatable(bool _participatable) public onlyChallenger {
    participatable = _participatable;
  } 

  // 存入押金
  function depositPenalty() public onlyChallenger onlyStarted {
    uint256 _deposit = depositAmount();

    require(deposit < _deposit, "Have been deposited!");

    penaltyToken.transferFrom(msg.sender, address(this), _deposit - deposit);
    deposit = _deposit;
  }

  // 提交博客
  function submitBlog(
    string memory title,
    string memory description,
    string memory url
  ) public onlyChallenger onlyStarted {
    // 记录博客提交情况
    blogSubmissions.push(
      BlogSubmission({
        cycle: currentCycle(),
        title: title,
        description: description,
        url: url,
        timestamp: block.timestamp
      })
    );
    emit SubmitBlog(challenger, currentCycle(), title, description, url);
  }

  // 设置白名单
  function setWhitelist(address[] memory _whitelist) public onlyChallenger {
    delete whitelist;
    for (uint256 i = 0; i < _whitelist.length; i++) {
      whitelist.push(_whitelist[i]);
    }
  }

  // endregion

  // region Participant calls

  // // 中途退出
  // function exit() public onlyStarted {
  //   uint256 len = participants.length;
  //   for (uint256 i = 0; i < len; i++) {
  //     if (msg.sender == participants[i]) {
  //       participants[i] = participants[len - 1];
  //       participants.pop();
  //       emit Exit(challenger, msg.sender);

  //       break;
  //     }
  //   }
  // }

  // endregion

  // region Private calls

  // 给参与者发放奖励
  function releaseToParticipants(address payer, uint256 totalAmount) private {
    IERC20 token = penaltyToken;
    uint256 totalTokens = totalSupply() - balanceOf(address(this));

    // 如果没有代币持有者，直接返回
    if (totalTokens == 0) return;

    for (uint256 i; i < participants.length; i++) {
      address participant = participants[i];
      // 计算参与者的代币占比
      uint256 participantAmount = totalAmount * balanceOf(participant) / totalTokens;
      
      if (participantAmount > 0) {
        if (payer == address(this)) // 如果payer是合约，直接发起转账
          token.transfer(participant, participantAmount);
        else // 否则通过授权转账
          token.transferFrom(payer, participant, participantAmount);

        emit Release(challenger, currentCycle(), participantAmount);
      }
    }
  }

  // 周期成功回调
  function onCyclePass() private {
  }
  // 周期失败回调
  function onCycleFailed() private {
    IERC20 token = penaltyToken;
    uint256 balance = token.balanceOf(challenger);
    uint256 amount = penaltyAmount;

    if (balance < amount || !isChallengerApproved()) { // 如果余额或授权数量不足
      noBalanceCount++;

      // 如果两次余额不足
      if (noBalanceCount >= 2) {
        // 将剩余押金平均分给参与者
        releaseToParticipants(address(this), deposit);
        deposit = 0;
        endChallenge(false);
      }

      // 如果有足够的押金
      else if (deposit >= amount) {
        // 扣除并释放惩罚金（通过押金的方式）
        releaseToParticipants(address(this), amount);
        deposit -= amount;
      }

      // 否则结束挑战
      else endChallenge(false);
    }
    // 如果余额和授权充足，扣除并释放惩罚金
    else releaseToParticipants(challenger, amount);
  }

  // 结束挑战
  function endChallenge(bool success) private {
    // 挑战成功
    if (success) onChallengePass();
    // 挑战失败
    else onChallengeFailed();

    emit ChallengeEnd(challenger, success);

    withdrawPenaltyToken();
    // 标记挑战为已结束
    started = false;
    deposit = 0;
  }
  // 提取押金
  function withdrawPenaltyToken() private {
    penaltyToken.transfer(challenger, penaltyToken.balanceOf(address(this)));
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
