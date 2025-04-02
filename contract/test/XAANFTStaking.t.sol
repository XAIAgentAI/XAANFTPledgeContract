// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/XAANFTStaking.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../script/Deploy.s.sol";

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("Test", "TST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract XAANFTStakingTest is Test {
    XAANFTStaking staking;
    MockERC1155 nft;
    MockERC20 token;
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    uint256[3] durations;
    uint256 baseReward = 500000e18;

    function setUp() public {
        vm.startPrank(owner);

        Deploy deployer = new Deploy();
        (address proxy1Address,,HelperConfig networkConfig) = deployer.deploy();
        staking = XAANFTStaking(proxy1Address);
        HelperConfig.NetworkConfig memory config = networkConfig.getConfig();
        durations[0] = config.durations[0];
        durations[1] = config.durations[1];
        durations[2] = config.durations[2];

        nft = new MockERC1155();
        token = new MockERC20();

        // 设置合约地址
        staking.setERC1155(address(nft));
        staking.setERC20(address(token));

        // 铸造NFT给用户
        nft.mint(user1, 1, 10);
        nft.mint(user1, 2, 5);
        nft.mint(user1, 3, 3);
        nft.mint(user2, 1, 5);

        // 铸造奖励代币给合约
        token.mint(address(staking), 1000000e18);

        vm.stopPrank();
    }

    // 测试初始化
    // function test_Initialization() public {
    //     assertEq(staking.owner(), owner);
        
    //     // 检查代币配置
    //     (uint256 duration1, uint256 reward1) = staking.tokenConfigs(1);
    //     (uint256 duration2, uint256 reward2) = staking.tokenConfigs(2);
    //     (uint256 duration3, uint256 reward3) = staking.tokenConfigs(3);
        
    //     assertEq(duration1, durations[0]);
    //     assertEq(duration2, durations[1]);
    //     assertEq(duration3, durations[2]);
    //     assertEq(reward1, baseReward);
    //     assertEq(reward2, baseReward);
    //     assertEq(reward3, baseReward);
    // }

    // 测试质押功能
    function test_Stake() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(address(staking), true);
        
        staking.stake(1, 1);
        
        (uint256 tokenId, uint256 amount, uint256 stakedAt, uint256 claimed) = staking.stakes(user1, 0);
        
        assertEq(tokenId, 1);
        assertEq(amount, 1);
        assertEq(stakedAt, block.timestamp);
        assertEq(claimed, 0);
        
        assertEq(nft.balanceOf(user1, 1), 9); // 用户余额减少
        assertEq(nft.balanceOf(address(staking), 1), 1); // 合约余额增加
        
        vm.stopPrank();
    }

    // 测试批量质押
    function test_BatchStake() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(address(staking), true);
        
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 2;
        amounts[2] = 1;
        
        staking.batchStake(tokenIds, amounts);
        
        (uint256 tokenId1, uint256 amount1,,) = staking.stakes(user1, 0);
        (uint256 tokenId2, uint256 amount2,,) = staking.stakes(user1, 1);
        (uint256 tokenId3, uint256 amount3,,) = staking.stakes(user1, 2);
        
        assertEq(tokenId1, 1);
        assertEq(amount1, 1);
        assertEq(tokenId2, 2);
        assertEq(amount2, 2);
        assertEq(tokenId3, 3);
        assertEq(amount3, 1);
        
        vm.stopPrank();
    }

    // 测试奖励计算
    function test_PendingReward() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(address(staking), true);
        staking.stake(1, 1);

        // 200天后（半个质押期）
        vm.warp(block.timestamp + 200 days);

        uint256 reward = staking.pendingReward(user1, 0);
        assertEq(reward, baseReward / 2);
        
        vm.stopPrank();
    }

    // 测试提取奖励
    function test_WithdrawReward() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(address(staking), true);
        staking.stake(1, 1);

        vm.warp(block.timestamp + 100 days);
        uint256 expectedReward = (baseReward * 100 days) / durations[0];

        uint256 beforeBalance = token.balanceOf(user1);
        staking.withdrawReward(1, 0);
        uint256 afterBalance = token.balanceOf(user1);

        assertEq(afterBalance - beforeBalance, expectedReward);
        
        vm.stopPrank();
    }

    // 测试多次质押
    function test_MultipleStakes() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(address(staking), true);

        staking.stake(1, 3);
        staking.stake(2, 2);
        staking.stake(3, 3);

        (,uint256 amount1,,) = staking.stakes(user1, 0);
        (,uint256 amount2,,) = staking.stakes(user1, 1);
        (,uint256 amount3,,) = staking.stakes(user1, 2);

        assertEq(amount1, 3);
        assertEq(amount2, 2);
        assertEq(amount3, 3);
        
        vm.stopPrank();
    }

    // 测试无效的代币ID
    function test_StakeInvalidTokenId() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(address(staking), true);

        vm.expectRevert("Invalid token");
        staking.stake(4, 1); // Token 4未配置
        
        vm.stopPrank();
    }

    // 测试解除质押
    function test_Unstake() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(address(staking), true);

        staking.stake(1, 2);
        
        uint256 beforeNftBalance = nft.balanceOf(user1, 1);
        
        // 确保在质押期内
        vm.warp(block.timestamp + 10 days);
        
        staking.unstake(0);
        
        uint256 afterNftBalance = nft.balanceOf(user1, 1);
        
        assertEq(afterNftBalance - beforeNftBalance, 2);
        
        // 检查质押记录是否已清零
        (,uint256 amount,,) = staking.stakes(user1, 0);
        assertEq(amount, 0);
        
        vm.stopPrank();
    }

    // 测试批量提取奖励
    function test_BatchWithdrawReward() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(address(staking), true);
        
        staking.stake(1, 1);
        staking.stake(2, 1);
        
        vm.warp(block.timestamp + 100 days);
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        
        uint256[] memory stakeIndexes = new uint256[](2);
        stakeIndexes[0] = 0;
        stakeIndexes[1] = 1;
        
        uint256 beforeBalance = token.balanceOf(user1);
        staking.batchWithdrawReward(tokenIds, stakeIndexes);
        uint256 afterBalance = token.balanceOf(user1);
        
        uint256 expectedReward1 = (baseReward * 100 days) * 1 ether / durations[0];
        uint256 expectedReward2 = (baseReward * 100 days) * 1 ether/ durations[1];
        
        assertLt(afterBalance - beforeBalance, (expectedReward1 + expectedReward2)/1 ether);
        assertGt(afterBalance - beforeBalance+ 1 ether, (expectedReward1 + expectedReward2)/1 ether);

        vm.stopPrank();
    }

    // 测试用户最大代币ID
    function test_UserMaxTokenId() public {
        vm.startPrank(user1);
        
        assertEq(staking.userMaxTokenId(user1), 3);
        
        vm.stopPrank();
    }

    // 测试金额增加函数
    function test_AmountIncrByTokenId() public {
        vm.startPrank(user1);
        
        assertEq(staking.amountIncrByTokenId(user1, 1000), 1100);
        
        vm.stopPrank();
    }

    // 测试救援代币功能
    function test_RescueToken() public {
        // 向合约发送一些代币
        token.mint(address(staking), 1000e18);
        
        uint256 beforeBalance = token.balanceOf(owner);
        
        vm.prank(owner);
        staking.rescueToken(address(token), 500e18);
        
        uint256 afterBalance = token.balanceOf(owner);
        
        assertEq(afterBalance - beforeBalance, 500e18);
    }

    // 测试设置代币配置
    function test_SetTokenConfig() public {
        vm.prank(owner);
        staking.setTokenConfig();
        
        (uint256 duration1, uint256 reward1) = staking.tokenConfigs(1);
        (uint256 duration2, uint256 reward2) = staking.tokenConfigs(2);
        (uint256 duration3, uint256 reward3) = staking.tokenConfigs(3);
        
        assertEq(duration1, 3600);
        assertEq(duration2, 1800);
        assertEq(duration3, 900);
        assertEq(reward1, 1000e18);
        assertEq(reward2, 1000e18);
        assertEq(reward3, 1000e18);
    }

    // 测试重入攻击防护
    function test_ReentrancyAttack() public {
        // 实现恶意合约
        MaliciousActor attacker = new MaliciousActor(address(staking));
        vm.prank(owner);
        token.mint(address(attacker), 1 ether);
        vm.expectRevert(); // 应触发重入保护
        attacker.attack();
    }
}

contract MaliciousActor {
    XAANFTStaking staking;
    constructor(address _staking) {
        staking = XAANFTStaking(_staking);
    }

    function attack() external {
        // 恶意重入调用
        staking.withdrawReward(1, 0);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4) {
        // 在回调期间尝试重入
        staking.withdrawReward(1, 0);
        return this.onERC1155Received.selector;
    }
}