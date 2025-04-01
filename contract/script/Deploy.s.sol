// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {XAANFTStaking} from "../src/XAANFTStaking.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {console} from "forge-std/Test.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

contract Deploy is Script {
    function run() external returns (address proxy, address logic) {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey;

        if (
            bytes(privateKeyString).length > 0 && bytes(privateKeyString)[0] == "0" && bytes(privateKeyString)[1] == "x"
        ) {
            deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        } else {
            deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        }

        vm.startBroadcast(deployerPrivateKey);

        (proxy, logic,) = deploy();
        vm.stopBroadcast();
        console.log("Proxy Contract deployed at:", proxy);
        console.log("Logic Contract deployed at:", logic);
        return (proxy, logic);
    }

    function deploy() public returns (address proxy, address logic, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        Options memory opts;
        logic = Upgrades.deployImplementation("XAANFTStaking.sol:XAANFTStaking", opts);


        proxy = Upgrades.deployUUPSProxy(
            "XAANFTStaking.sol:XAANFTStaking",
            abi.encodeCall(
                XAANFTStaking.initialize, (config.owner, config.nft, config.xaa, config.durations, config.baseReward)
            )
        );
        return (proxy, logic, helperConfig);
    }
}
