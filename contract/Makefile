install:
	forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit && forge install OpenZeppelin/openzeppelin-contracts --no-commit && forge remappings > remappings.txt && forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-commit

build:
	forge build

test:
	forge test

fmt:
	forge fmt
deploy-dbc-testnet:
	source .env && forge script script/Deploy.s.sol:Deploy --rpc-url dbc-testnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy

upgrade-dbc-testnet:
	source .env && forge script script/Upgrade.s.sol:Upgrade --rpc-url dbc-testnet --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy

deploy-dbc-mainnet:
	source .env && forge script script/Deploy.s.sol:Deploy --rpc-url dbc-mainnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $MAIN_NET_VERIFIER_URL --force --skip-simulation --legacy

upgrade-dbc-mainnet:
	source .env && forge script script/Upgrade.s.sol:Upgrade --rpc-url dbc-mainnet --broadcast --verify --verifier blockscout --verifier-url $MAIN_NET_VERIFIER_URL  --force --skip-simulation  --legacy

	source .env && forge verify-contract --chain 19880818  --compiler-version v0.8.26 --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL 0xc488736c09ab088e5203b48d973dca30581d6118  src/XAANFTStaking.sol:XAANFTStaking
