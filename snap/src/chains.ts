import { defineChain } from 'viem'

export const dbcChain = defineChain({
    id: 19880818,
    name: 'DBC',
    network: 'dbc',
    nativeCurrency: {
        decimals: 18,
        name: 'DBC',
        symbol: 'DBC',
    },
    rpcUrls: {
        default: {
            http: ['https://rpc.dbcwallet.io'],
        },
        public: {
            http: ['https://rpc.dbcwallet.io'],
        },
    },
    blockExplorers: {
        default: {
            name: 'DBCScan',
            url: 'https://dbcscan.io',
        },
    },
})