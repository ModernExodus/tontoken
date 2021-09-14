const Web3 = require('web3');
const { Chain, Hardfork } = require('@ethereumjs/common');
const { FeeMarketEIP1559Transaction } = require('@ethereumjs/tx');
const { projectId, privateKey, publicKey } = require('../secrets.js');
const Tontoken = require('../build/contracts/Tontoken.json');

const network = process.argv.slice(2)[0].toLowerCase();
if (network !== 'mainnet' && network !== 'ropsten') {
    throw new Error('Unsupported network ', network);
}

console.log(`Deploying Tontoken to ${network} blockchain...`);
deploySmartContract(getWeb3Instance(network), Tontoken.bytecode, Tontoken.abi).then(() => {
    console.log('Deployment completed');
    process.exit(0);
}, (err) => {
    console.log('Deployment failed!', err);
    process.exit(1);
});

function getWeb3Instance(network) {
    // provider to connect to blockchain
    return new Web3(new Web3.providers.HttpProvider(`https://${network}.infura.io/v3/${projectId}`));
}

async function deploySmartContract(web3, bytecode, abi) {
    // create deployment transaction
    const tontokenContract = new web3.eth.Contract(abi);
    const tontokenCreateTrx = tontokenContract.deploy({
        data: bytecode,
        arguments: [true]
    });

    const rawTransaction = {
        data: tontokenCreateTrx.encodeABI(),
        gasLimit: web3.utils.toHex(5000000),
        nonce: web3.utils.toHex(await web3.eth.getTransactionCount(publicKey)),
        maxFeePerGas: web3.utils.toHex(50e9),
        maxPriorityFeePerGas: web3.utils.toHex(10e9),
        chainId: web3.currentProvider.host.indexOf('mainnet') !== -1 ? '0x01' : '0x03',
        type: '0x02'
    };
    const unsignedTransaction = FeeMarketEIP1559Transaction.fromTxData(rawTransaction, {chain: Chain.Ropsten, hardfork: Hardfork.London});
    const signedTransaction = unsignedTransaction.sign(Buffer.from(privateKey, 'hex'));

    await web3.eth.sendSignedTransaction('0x' + signedTransaction.serialize().toString('hex'), (err, hash) => {
        if (err) {
            throw new Error(err);
        } else {
            console.log('Transaction hash:', hash);
        }
    });
}