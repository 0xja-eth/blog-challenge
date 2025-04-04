// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BlogChallenge.sol";

contract ChallengeFactory is Ownable {
    event ChallengeCreated(address indexed challenger, address indexed challenge);
    event ChallengeImplementationUpdated(bytes32 indexed codeHash);

    BlogChallenge[] public challenges;
    mapping(address => BlogChallenge[]) public challengerToChallenges;

    // 挑战合约的字节码
    bytes public challengeCode = type(BlogChallenge).creationCode;
    
    constructor() Ownable(msg.sender) { }

    // 更新挑战合约实现
    function updateChallengeImplementation(bytes memory _newCode) external onlyOwner {
        require(_newCode.length > 0, "Invalid implementation");
        challengeCode = _newCode;
        emit ChallengeImplementationUpdated(keccak256(_newCode));
    }

    function challengeCount() external view returns (uint256) {
        return challenges.length;
    }
    function challengerChallengeCount(address challenger) external view returns (uint256) {
        return challengerToChallenges[challenger].length;
    }

    function createChallenge(
        uint256 startTime,
        uint256 cycle,
        uint256 numberOfCycles,
        address penaltyToken,
        uint256 penaltyAmount,
        uint256 maxParticipants,
        bool freeMode
    ) external returns (address) {
        // 使用 abi.encodeWithSelector 来编码构造函数调用
        bytes memory constructorArgs = abi.encode(
            challenges.length + 1, // _id
            msg.sender, // _challenger
            startTime,
            cycle,
            numberOfCycles,
            penaltyToken,
            penaltyAmount,
            maxParticipants,
            freeMode
        );

        // 计算salt（使用构造函数参数的hash作为salt）
        bytes32 salt = keccak256(constructorArgs);

        // 准备创建合约的字节码
        bytes memory bytecode = bytes.concat(
            challengeCode,
            constructorArgs
        );

        // 使用create2部署合约
        address challengeAddress;
        assembly {
            challengeAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            // if iszero(extcodesize(challengeAddress)) {
            //     revert(0, 0)
            // }
        }
        require(challengeAddress != address(0), "Create2 failed");
        
        BlogChallenge challenge = BlogChallenge(challengeAddress);
        challenges.push(challenge);
        challengerToChallenges[msg.sender].push(challenge);

        emit ChallengeCreated(msg.sender, challengeAddress);
        
        return challengeAddress;
    }

    // 预计算合约地址
    function predictChallengeAddress(
        uint256 startTime,
        uint256 cycle,
        uint256 numberOfCycles,
        address penaltyToken,
        uint256 penaltyAmount,
        uint256 maxParticipants,
        bool freeMode
    ) public view returns (address) {
        bytes memory constructorArgs = abi.encode(
            challenges.length,
            msg.sender,
            startTime,
            cycle,
            numberOfCycles,
            penaltyToken,
            penaltyAmount,
            maxParticipants,
            freeMode
        );
        bytes32 salt = keccak256(constructorArgs);
        
        bytes memory bytecode = bytes.concat(
            challengeCode,
            constructorArgs
        );
        
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(bytecode)
        )))));
    }
}
