
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/forge-std/src/interfaces/IERC20.sol";

contract YieldFarming{

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public rewardRate;  //Reward tokens distributed per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    uint256 private _totalSupply;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(IERC20 _stakingToken, IERC20 _rewardToken, uint256 _rewardRate){
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    modifier updateReward(address account){
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if(account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if(_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + ((block.timestamp -lastUpdateTime) * rewardRate * 1e18 /(_totalSupply));
    }

    function earned(address account) public view returns (uint256) {
        return balances[account]
               * (rewardPerToken() - (userRewardPerTokenPaid[account]))
               /(1e18)
               +(rewards[account]);
    }

    function stake(uint256 amount) external updateReward(msg.sender){
        require(amount > 0, "Cannot stake 0 tokens");
        _totalSupply = _totalSupply + amount;
        balances[msg.sender] = balances[msg.sender] + amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender){
        require(amount >0 ,"cannot withdraw 0 tokens");
        _totalSupply = _totalSupply - amount;
         balances[msg.sender] = balances[msg.sender] - amount;
         stakingToken.transfer(msg.sender, amount);
         emit Withdrawn(msg.sender, amount);
    }

    function getReward() public updateReward(msg.sender){
        uint256 reward = rewards[msg.sender];
        if(reward > 0){
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }
}