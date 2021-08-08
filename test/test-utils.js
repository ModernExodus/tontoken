// utilities to help with unit testing
module.exports.assertVmException = async function assertVmException(func, ...args) {
    let vmException = false;
    try {
        await func(...args);
    } catch {
        vmException = true;
    }
    assert.ok(vmException);
};

module.exports.mineBlocks = async function mineBlocks(numBlocks) {
    let i = 0;
    while (i < numBlocks) {
        await web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_mine',
            params: [],
            id: 0
        }, () => {});
        i++;
    }
};

module.exports.convertToBorks = function(tontokens) {
    return tontokens * 1000000;
};

module.exports.convertToTontokens = function(borks) {
    return borks / 1000000;
};

module.exports.calculateBorkMatch = function(borks) {
    return borks >= 64 ? Math.floor(borks / 64) : 1;
};