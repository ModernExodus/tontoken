const { ethAddresses } = require('./address-data.js');

const KeyGenerator = artifacts.require('UniqueKeyGeneratorProxy');

// expect 2nd and 3rd tests to take about 1.5 minutes per 10 numSaltChanges
const numSaltShakes = 5;
contract('UniqueKeyGenerator', async accounts => {
    let keyGenerator;
    let keySet;

    beforeEach(async () => {
        keyGenerator = await KeyGenerator.new();
        keySet = new Set();
    });

    it('should have a key collision if it receives the same input before changing salt', async () => {
        for (let i = 0; i < 5; i++) {
            const genKey = await keyGenerator.generateKeyP.call(accounts[i]);
            if (keySet.has(genKey)) {
                assert.fail('Key collision happened prematurely');
            }
            keySet.add(genKey);
        }
        const dupKey = await keyGenerator.generateKeyP.call(accounts[0]);
        assert.ok(keySet.has(dupKey));
    });

    it('should not have an address key collision as it changes salt', async () => {
        const addressList = ethAddresses.concat(accounts);
        for (let i = 0; i < numSaltShakes; i++) {
            for (const address of addressList) {
                const genKey = await keyGenerator.generateKeyP.call(address);
                if (keySet.has(genKey)) {
                    assert.fail('Key collision');
                }
                keySet.add(genKey);
            }
            await keyGenerator.changeSalt.sendTransaction();
        }
    });

    it('should not have a uint256 key collision as it changes salt', async () => {
        for (let i = 0; i < numSaltShakes; i++) {
            for (let j = 0; j < 50; j++) {
                const genKey = await keyGenerator.methods['generateKeyP(uint256)'].call(j);
                if (keySet.has(genKey)) {
                    assert.fail('Key collision');
                }
                keySet.add(genKey);
            }
            await keyGenerator.changeSalt.sendTransaction();
        }
    });
});