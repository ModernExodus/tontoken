const { ethAddresses } = require('./address-data.js');

const KeyGenerator = artifacts.require('UniqueKeyGeneratorProxy');

// expect 2nd test to take about 1.5 minutes per 10 numSaltChanges
const numSaltChanges = 25;
contract('UniqueKeyGenerator', async accounts => {
    let keyGenerator;
    let keySet;

    beforeEach(async () => {
        keyGenerator = await KeyGenerator.new();
        keySet = new Set();
    });

    it('should have a key collision if it receives the same input before changing salt', async () => {
        for (let i = 0; i < 5; i++) {
            const genKey = await keyGenerator.generateKey.call(accounts[i]);
            if (keySet.has(genKey)) {
                assert.fail('Key collision happened prematurely');
            }
            keySet.add(genKey);
        }
        const dupKey = await keyGenerator.generateKey.call(accounts[0]);
        assert.ok(keySet.has(dupKey));
    });

    it('should not have a key collision as it changes salt', async () => {
        const addressList = ethAddresses.concat(accounts);
        for (let i = 0; i < numSaltChanges; i++) {
            for (const address of addressList) {
                const genKey = await keyGenerator.generateKey.call(address);
                if (keySet.has(genKey)) {
                    assert.fail('Key collision');
                }
                keySet.add(genKey);
            }
            await keyGenerator.changeSalt.sendTransaction();
        }
    });
});