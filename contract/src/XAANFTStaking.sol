// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @custom:oz-upgrades-from OldXAANFTStaking
contract XAANFTStaking is
    IERC1155Receiver,
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    address public canUpgradeAddress;

    struct TokenConfig {
        uint256 duration; // staking period（seconds）
        uint256 rewardAmount; // reward amount per nft（wei）
    }

    IERC1155 public erc1155;
    IERC20 public erc20;

    // tokenId => config
    mapping(uint256 => TokenConfig) public tokenConfigs;

    // staking records（address => Stake[]）
    mapping(address => Stake[]) public stakes;

    mapping(address => uint256[]) public users2Indexes;

    // address => tokenId => bool
    mapping(address => mapping(uint256 => bool)) public user2TokenIds;

    struct Stake {
        uint256 tokenId;
        uint256 amount; // stake amount（wei）
        uint256 stakedAt;
        uint256 claimed;
    }

    event Staked(address indexed user, uint256 tokenId, uint256 amount);
    event WithdrawnReward(address indexed user, uint256 tokenId, uint256 reward);
    event Unstaked(address indexed user, uint256 tokenId, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        address _erc1155,
        address _erc20,
        uint256[3] memory durations,
        uint256 baseReward
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(owner);
        __ReentrancyGuard_init();

        erc1155 = IERC1155(_erc1155);
        erc20 = IERC20(_erc20);

        tokenConfigs[1] = TokenConfig(durations[0], baseReward);
        tokenConfigs[2] = TokenConfig(durations[1], baseReward);
        tokenConfigs[3] = TokenConfig(durations[2], baseReward);
    }

    function onERC1155BatchReceived(
        address, /* unusedParameter */
        address, /* unusedParameter */
        uint256[] calldata, /* unusedParameter */
        uint256[] calldata, /* unusedParameter */
        bytes calldata /* unusedParameter */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC1155Received(
        address, /* unusedParameter */
        address, /* unusedParameter */
        uint256, /* unusedParameter */
        uint256, /* unusedParameter */
        bytes calldata /* unusedParameter */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation != address(0), "Zero Address");
        require(msg.sender == canUpgradeAddress, "can not upgrade");
    }

    function setUpgradeAddress(address addr) external onlyOwner {
        canUpgradeAddress = addr;
    }

    function setERC1155(address _erc1155) external onlyOwner {
        erc1155 = IERC1155(_erc1155);
    }

    function setERC20(address _erc20) external onlyOwner {
        erc20 = IERC20(_erc20);
    }

    function stake(uint256 tokenId, uint256 amount) public {
        TokenConfig memory config = tokenConfigs[tokenId];
        require(config.duration > 0, "Invalid token");

        erc1155.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        stakes[msg.sender].push(Stake(tokenId, amount, block.timestamp, 0));
        user2TokenIds[msg.sender][tokenId] = true;
        users2Indexes[msg.sender].push(stakes[msg.sender].length - 1);
        emit Staked(msg.sender, tokenId, amount);
    }

    function batchStake(uint256[] calldata tokenId, uint256[] calldata amounts) public nonReentrant {
        require(tokenId.length <= 3, "max stake item is 3 every time");
        require(tokenId.length == amounts.length, "Invalid input");
        for (uint256 i = 0; i < tokenId.length; i++) {
            stake(tokenId[i], amounts[i]);
        }
    }

    function batchWithdrawReward(uint256[] calldata tokenIds, uint256[] calldata stakeIndexes) external nonReentrant {
        require(tokenIds.length == stakeIndexes.length, "Invalid input");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            withdrawReward(tokenIds[i], stakeIndexes[i]);
        }
    }

    function withdrawReward(uint256 tokenId, uint256 stakeIndex) public {
        TokenConfig memory config = tokenConfigs[tokenId];
        require(config.duration > 0, "Invalid token");

        Stake storage stakeRecord = stakes[msg.sender][stakeIndex];
        require(stakeRecord.amount > 0, "Already withdrawn");

        uint256 _pendingReward = pendingReward(msg.sender, stakeIndex);

        stakeRecord.claimed += _pendingReward;
        require(_pendingReward > 0, "No reward");
        require(erc20.transfer(msg.sender, _pendingReward), "transfer failed");

        emit WithdrawnReward(msg.sender, tokenId, _pendingReward);
    }

    function pendingReward(address user, uint256 stakeIndex) public view returns (uint256) {
        Stake memory stakeRecord = stakes[user][stakeIndex];
        TokenConfig memory config = tokenConfigs[stakeRecord.tokenId];

        uint256 elapsed = block.timestamp - stakeRecord.stakedAt;
        uint256 rewardRatio = elapsed > config.duration ? 1e18 : (elapsed * 1e18) / config.duration;

        return (stakeRecord.amount * config.rewardAmount * rewardRatio) / 1e18 - stakeRecord.claimed;
    }

    function unstake(uint256 stakeIndex) external nonReentrant {
        Stake storage stakeRecord = stakes[msg.sender][stakeIndex];
        uint256 tokenId = stakeRecord.tokenId;
        require(stakeRecord.amount > 0, "No staked");
        TokenConfig memory config = tokenConfigs[tokenId];
        require(config.duration > 0, "Invalid token");
        require(stakeRecord.stakedAt + config.duration > block.timestamp, "Staking period not over");
        uint256 finalReward = pendingReward(msg.sender, stakeIndex);
        if (finalReward > 0) {
            stakeRecord.claimed += finalReward;
            require(erc20.transfer(msg.sender, finalReward), "transfer failed");
        }
        erc1155.safeTransferFrom(address(this), msg.sender, tokenId, stakeRecord.amount, "");
        stakeRecord.amount = 0;
        emit Unstaked(msg.sender, tokenId, stakeRecord.amount);
    }

    function userIndexes(address holder) external view returns (uint256[] memory) {
        return users2Indexes[holder];
    }

    function amountIncrByTokenId(address user, uint256 amount) external view returns (uint256) {
        if (userMaxTokenId(user) == 3) {
            return amount * 110 / 100;
        }

        if (userMaxTokenId(user) == 2) {
            return amount * 105 / 100;
        }
        if (userMaxTokenId(user) == 1) {
            return amount * 103 / 100;
        }
        return amount;
    }

    function userMaxTokenId(address user) public view returns (uint256) {
        if (user2TokenIds[user][3] || erc1155.balanceOf(user, 3) > 0) {
            return 3;
        }

        if (user2TokenIds[user][2] || erc1155.balanceOf(user, 2) > 0) {
            return 2;
        }

        if (user2TokenIds[user][1] || erc1155.balanceOf(user, 1) > 0) {
            return 1;
        }

        return 0;
    }

    function rescueToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function setTokenConfig() external {
        tokenConfigs[1] = TokenConfig(3600, 1000e18);
        tokenConfigs[2] = TokenConfig(1800, 1000e18);
        tokenConfigs[3] = TokenConfig(900, 1000e18);
    }
}
