// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {YieldFarming} from "../src/YieldFarming.sol";
import "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/forge-std/src/interfaces/IERC20.sol";

// Mock ERC20 Token for testing 
contract ERC20Mock is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ){
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) public{
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external override returns (bool){
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to , amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool){
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract YieldFarmingTest is Test {
    
    YieldFarming public yieldFarming;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    address public user1;
    address public user2;

    function setUp() public {

     stakingToken = new ERC20Mock("StakingToken", "STK", 18);
     rewardToken = new ERC20Mock("RewardToken", "RWD", 18);

     uint256 rewardRate = 1 * 1e18;

     // Deploy the yieldfarming 
     yieldFarming = new YieldFarming(stakingToken , rewardToken, rewardRate);

     // Assign test users 
     user1 = address(0x1);
     user2 = address(0x2);

     // Mint tokens to users and approve the YieldFarming contract
     ERC20Mock(address(stakingToken)).mint(user1, 1000 * 1e18);
     ERC20Mock(address(stakingToken)).mint(user2, 1000 * 1e18);

     vm.prank(user1);
     stakingToken.approve(address(yieldFarming), type(uint256).max);

     vm.prank(user2);
     stakingToken.approve(address(yieldFarming), type(uint256).max);

     ERC20Mock(address(rewardToken)).mint(address(yieldFarming), 1000 * 1e18);
     
    }

    function testInitialSetup() public {
        assertEq(stakingToken.balanceOf(user1), 1000 * 1e18);
        assertEq(stakingToken.balanceOf(user2), 1000 * 1e18);
        assertEq(rewardToken.balanceOf(address(yieldFarming)), 1000 * 1e18);
    }

    function testStakeAndEarnRewards() public {
        //simulate user1 stake tokens
        vm.prank(user1);
        yieldFarming.stake(100 * 1e18);

        vm.warp(block.timestamp + 10); //Forward time by 10 seconds

        // check earned rewards after 10s
        uint256 earnedRewards = yieldFarming.earned(user1);
        assertEq(earnedRewards , 10 * 1e18); // Expecting 10 reward tokens

        //Simulate user1 withdrawing rewards
        vm.prank(user1);
        yieldFarming.getReward();
        assertEq(rewardToken.balanceOf(user1), 10 * 1e18); //User1 should receive 10 reward tokens
    }

    function testWithdrawStake() public {
        // Simulate user1 staking tokens
        vm.startPrank(user1);
        yieldFarming.stake(100 * 1e18);

        vm.warp(block.timestamp + 10); //forward time by 10s

        yieldFarming.withdraw(50 * 1e18); // user withdraws 50 staken token
 
        assertEq(stakingToken.balanceOf(user1), 950 * 1e18); //user1 should have 950 tokens left
        assertEq(stakingToken.balanceOf(address(yieldFarming)), 50 * 1e18);

        vm.stopPrank();
    }

    function testExit() public {
        // Simulate user1 staking tokens
        vm.startPrank(user1);
        yieldFarming.stake(100 * 1e18);

        vm.warp(block.timestamp + 10);

        yieldFarming.exit(); // user exits, withdrawing stake and rewards

        assertEq(stakingToken.balanceOf(user1), 1000 * 1e18);
        assertEq(rewardToken.balanceOf(user1), 10 * 1e18);

        vm.stopPrank();
    }

    function testMultipleStakers() public {
        vm.prank(user1);
        yieldFarming.stake(100 * 1e18);

        vm.prank(user2);
        yieldFarming.stake(200 * 1e18);

        vm.warp(block.timestamp + 10);  // forward time by 10s

        //earned rewards for user 1&2
        uint256 earnedRewardsUser1 = yieldFarming.earned(user1);
        uint256 earnedRewardsUser2 = yieldFarming.earned(user2);

        // Precomputed expected rewards
        
        //the total rewards generated are 10 * 1e18 tokens in 10s
        uint256 totalRewards = 10 * 1e18;

        uint256 expectedUser1Rewards = (totalRewards * 100) / 300; // 100/300 of total rewards
        uint256 expectedUser2Rewards = (totalRewards * 200) / 300;  // 200/300 of total rewards

        assertEq(earnedRewardsUser1, expectedUser1Rewards, "incorrect User1 reward calculation"); // it may this test fail 3333333333333333300 != 3333333333333333333 This is likely due to precision issues when performing arithmetic operations with large numbers, particularly when dealing with decimals in Solidity.
        assertEq(earnedRewardsUser2, expectedUser2Rewards, "incorrect User2 reward calculation");
    }

} 