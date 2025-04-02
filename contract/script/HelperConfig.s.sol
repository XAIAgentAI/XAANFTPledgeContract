// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Constans {
    uint256 constant DBC_MAINNET_CHAINID = 19880818;
    uint256 constant DBC_TESTNET_CHAINID = 19850818;
    uint256 constant DBC_LOCAL_CHAINID = 31337;
    address constant DBC_MAINNET_NFT = address(0x9a75157f40626F8A71B7a848ADb3d5670155664C);
    address constant DBC_MAINNET_XAA = address(0x16d83F6B17914a4e88436251589194CA5AC0f452);
}

contract HelperConfig is Constans {
    struct NetworkConfig {
        address owner;
        address nft;
        address xaa;
        uint256[3] durations;
        uint256 baseReward;
    }

    NetworkConfig public networkConfig;

    constructor() {
        if (block.chainid == DBC_MAINNET_CHAINID) {
            setConfig(getDBCMainnetConfig());
        }
        if (block.chainid == DBC_LOCAL_CHAINID) {
            setConfig(getLocalConfig());
        }
        setConfig(getLocalConfig());
    }

    function setConfig(NetworkConfig memory _networkConfig) public {
        networkConfig = _networkConfig;
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return networkConfig;
    }

    function getDBCMainnetConfig() public view returns (NetworkConfig memory) {
        uint256[3] memory durations = [uint256(400 days), uint256(300 days), uint256(200 days)];
        return NetworkConfig({
            owner: msg.sender,
            nft: DBC_MAINNET_NFT,
            xaa: DBC_MAINNET_XAA,
            durations: durations,
            baseReward: 500_000 ether
        });
    }

    function getLocalConfig() public pure returns (NetworkConfig memory) {
        uint256[3] memory durations = [uint256(400 days), uint256(300 days), uint256(200 days)];
        durations[0] = 400 days;
        durations[1] = 300 days;
        durations[2] = 200 days;

        return NetworkConfig({
            owner: address(0x01),
            nft: DBC_MAINNET_NFT,
            xaa: DBC_MAINNET_XAA,
            durations: durations,
            baseReward: 500_000 ether
        });
    }
}
