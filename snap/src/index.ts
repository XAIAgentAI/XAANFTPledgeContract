import { createPublicClient, http, parseAbiItem, formatEther } from 'viem';
import { dbcChain } from './chains';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import * as XLSX from 'xlsx';

dotenv.config();

interface Stake {
    tokenId: number;
    amount: bigint;
    stakedAt: number;
    claimed: bigint;
}

interface StakingSnapshot {
    address: string;
    stakes: Stake[];
    timestamp: number;
}

const CONTRACT_ADDRESS = '0xc488736c09ab088e5203b48d973dca30581d6118';
const RPC_URL = 'https://rpc.dbcwallet.io';

const ABI = [
    {
        inputs: [
            { name: '', type: 'address' },
            { name: '', type: 'uint256' }
        ],
        name: 'stakes',
        outputs: [
            { name: 'tokenId', type: 'uint256' },
            { name: 'amount', type: 'uint256' },
            { name: 'stakedAt', type: 'uint256' },
            { name: 'claimed', type: 'uint256' }
        ],
        stateMutability: 'view',
        type: 'function'
    },
    {
        anonymous: false,
        inputs: [
            { indexed: true, name: 'user', type: 'address' },
            { indexed: false, name: 'tokenId', type: 'uint256' },
            { indexed: false, name: 'amount', type: 'uint256' }
        ],
        name: 'Staked',
        type: 'event'
    }
];

async function getLogsInBatches(client: any, fromBlock: bigint | number, toBlock: bigint | number | 'latest', batchSize = 1000n) {
    const logs = [];
    let currentFromBlock = BigInt(fromBlock);
    const targetBlock = toBlock === 'latest' ? await client.getBlockNumber() : BigInt(toBlock);

    while (currentFromBlock <= targetBlock) {
        const currentToBlock = currentFromBlock + batchSize > targetBlock
            ? targetBlock
            : currentFromBlock + batchSize;

        console.log(`Fetching logs from block ${currentFromBlock} to ${currentToBlock}`);
        try {
            const batchLogs = await client.getLogs({
                address: CONTRACT_ADDRESS,
                event: parseAbiItem('event Staked(address indexed user, uint256 tokenId, uint256 amount)'),
                fromBlock: currentFromBlock,
                toBlock: currentToBlock
            });
            logs.push(...batchLogs);
        } catch (error) {
            console.error(`Error fetching logs for blocks ${currentFromBlock}-${currentToBlock}:`, error);
        }
        currentFromBlock = currentToBlock + 1n;
    }
    return logs;
}

async function main() {
    try {
        console.log('Connecting to DBC network...');
        const client = createPublicClient({
            chain: dbcChain,
            transport: http(RPC_URL, {
                timeout: 30000, // 30 seconds timeout
                retryCount: 3,
                retryDelay: 1000 // 1 second delay between retries
            })
        });

        // Get all staking events
        console.log('Fetching staking events in batches...');
        const events = await getLogsInBatches(client, 1550797n, 'latest');

        // Store unique addresses
        const uniqueAddresses = new Set<string>();
        events.forEach(event => {
            if (event.args?.user) {
                uniqueAddresses.add(event.args.user.toLowerCase());
            }
        });

        console.log(`Found ${uniqueAddresses.size} unique staking addresses`);

        // Get staking information for each address
        const snapshots: StakingSnapshot[] = [];
        let processedCount = 0;

        for (const address of uniqueAddresses) {
            try {
                const stakes: Stake[] = [];
                let index = 0;

                while (true) {
                    try {
                        const stake = await client.readContract({
                            address: CONTRACT_ADDRESS,
                            abi: ABI,
                            functionName: 'stakes',
                            args: [address, BigInt(index)]
                        }) as [bigint, bigint, bigint, bigint];

                        if (stake[1] === 0n) break;

                        stakes.push({
                            tokenId: Number(stake[0]),
                            amount: stake[1],
                            stakedAt: Number(stake[2]),
                            claimed: stake[3]
                        });

                        index++;
                    } catch (error) {
                        break;
                    }
                }

                if (stakes.length > 0) {
                    snapshots.push({
                        address,
                        stakes,
                        timestamp: Math.floor(Date.now() / 1000)
                    });
                }

                processedCount++;
                if (processedCount % 10 === 0) {
                    console.log(`Processed ${processedCount}/${uniqueAddresses.size} addresses`);
                }
            } catch (error) {
                console.error(`Error processing address ${address}:`, error);
            }
        }

        // Merge staking records with same address
        const mergedStakes = new Map<string, bigint>();

        for (const snapshot of snapshots) {
            let totalAmount = 0n;
            for (const stake of snapshot.stakes) {
                totalAmount += stake.amount;
            }
            mergedStakes.set(snapshot.address, totalAmount);
        }

        // Print merged staking information
        console.log('\nStaking Information Summary:');
        console.log('----------------------------------------');

        for (const [address, amount] of mergedStakes) {
            console.log(`\nStaking Address: ${address}`);
            console.log(`Total Staking Amount: ${amount}`);
            console.log('----------------------------------------');
        }

        console.log(`\nTotal Number of Staking Addresses: ${mergedStakes.size}`);

        // Prepare Excel data
        const stakingData = [];
        for (const [address, amount] of mergedStakes) {
            stakingData.push({
                'Staking Address': address,
                'Total Staking Amount': amount.toString()
            });
        }

        // Create workbook
        const wb = XLSX.utils.book_new();

        // Create staking information worksheet
        const ws = XLSX.utils.json_to_sheet(stakingData);
        XLSX.utils.book_append_sheet(wb, ws, 'Staking Information');

        // Ensure output directory exists
        const outputDir = path.join(__dirname, '../output');
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir);
        }

        // Generate filename with current time (HH:MM:SS)
        const now = new Date();
        const timeStr = now.toTimeString().split(' ')[0].replace(/:/g, '');
        const fileName = `staking-snap-${timeStr}.xlsx`;
        const filePath = path.join(outputDir, fileName);

        // Write Excel file
        XLSX.writeFile(wb, filePath);
        console.log(`\nExcel file exported to: ${filePath}`);
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

main();