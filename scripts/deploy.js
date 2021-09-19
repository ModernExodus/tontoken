const Web3 = require('web3');
const { Chain, Hardfork } = require('@ethereumjs/common');
const { FeeMarketEIP1559Transaction } = require('@ethereumjs/tx');
const { projectId, privateKey, publicKey } = require('../secrets.js');
const Tontoken = require('../build/contracts/Tontoken.json');

const parameters = process.argv.slice(2);
const network = parameters[0].toLowerCase();
const maxGas = parseInt(parameters[1] || 5000000, 10);
const maxFeePerGas = parseInt(parameters[2] || 50e9, 10);
const maxPriorityFeePerGas = parseInt(parameters[3] || 1e9, 10);
if (network !== 'mainnet' && network !== 'ropsten') {
    throw new Error('Unsupported network ', network);
}

console.log(`Deploying Tontoken to ${network} blockchain...`);
deploySmartContract(getWeb3Instance(network), Tontoken.bytecode, Tontoken.abi, {
    network: network,
    maxGas: maxGas,
    maxFeePerGas: maxFeePerGas,
    maxPriorityFeePerGas: maxPriorityFeePerGas
}).then(() => {
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

async function deploySmartContract(web3, bytecode, abi, options) {
    // create deployment transaction
    const tontokenContract = new web3.eth.Contract(abi);
    const tontokenCreateTrx = tontokenContract.deploy({
        data: bytecode,
        arguments: [true]
    });

    let gasLimit;
    const gasEstimate = await tontokenCreateTrx.estimateGas();
    if (gasEstimate > options.maxGas) {
        throw new Error(`Estimated gas (${gasEstimate}) is higher than max gas (${options.maxGas})`);
    } else if (options.maxGas - gasEstimate < 100000) {
        throw new Error(`Estimated gas (${gasEstimate}) is within 100000 of the specified max gas (${options.maxGas})`);
    } else {
        gasLimit = gasEstimate + 100000;
    }

    const rawTransaction = {
        data: tontokenCreateTrx.encodeABI(),
        gasLimit: web3.utils.toHex(gasLimit),
        nonce: web3.utils.toHex(await web3.eth.getTransactionCount(publicKey)),
        maxFeePerGas: web3.utils.toHex(options.maxFeePerGas),
        maxPriorityFeePerGas: web3.utils.toHex(options.maxPriorityFeePerGas),
        chainId: options.network === 'mainnet' ? '0x01' : '0x03',
        type: '0x02'
    };

    const unsignedTransaction = FeeMarketEIP1559Transaction.fromTxData(rawTransaction, 
        {chain: options.network === 'mainnet' ? Chain.Mainnet : Chain.Ropsten, hardfork: Hardfork.London});
    const signedTransaction = unsignedTransaction.sign(Buffer.from(privateKey, 'hex'));

    await web3.eth.sendSignedTransaction('0x' + signedTransaction.serialize().toString('hex'), (err, hash) => {
        if (err) {
            throw new Error(err);
        } else {
            console.log('Transaction hash:', hash);
        }
    });
}