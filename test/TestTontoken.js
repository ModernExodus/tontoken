const { assertVmException, convertToTontokens } = require('./test-utils.js');

const Tontoken = artifacts.require("Tontoken");

contract('Tontoken', async accounts => {
    let token;
    
    beforeEach(async () => {
        token = await Tontoken.new();
    });

    it('should put 1000000 Tontokens in the owner account', async () => {
        const ownerBalance = (await token.balanceOf.call(accounts[0])).toNumber();
        assert.strictEqual(convertToTontokens(ownerBalance), 1000000);
    });

    it('should transfer borks correctly', async () => {
        const balanceBeforeTransfer = (await token.balanceOf(accounts[0])).toNumber();
        await token.transfer.sendTransaction(accounts[1], 500, { from: accounts[0] });
        const account1Balance = (await token.balanceOf(accounts[0])).toNumber();
        const account2Balance = (await token.balanceOf(accounts[1])).toNumber();
        assert.strictEqual(account1Balance, balanceBeforeTransfer - 500);
        assert.strictEqual(account2Balance, 500);
    });

    it('should not transfer tokens if the sender does not have enough balance', async () => {
        const balance = (await token.balanceOf(accounts[2])).toNumber();
        assert.strictEqual(balance, 0);
        await assertVmException(token.transfer.sendTransaction, accounts[0], 500, { from: accounts[2] });
    });

    it('should allow an address to delegate a spender to send a certain amount', async () => {
        const owner = accounts[0];
        const delegate = accounts[2];

        await token.approve.sendTransaction(delegate, 100, { from: owner});
        const allowance = (await token.allowance.call(owner, delegate)).toNumber();
        assert.strictEqual(allowance, 100);
    });

    it('should allow a delegated spender to send a certain amount', async () => {
        const owner = accounts[0];
        const delegate = accounts[2];
        await token.approve.sendTransaction(delegate, 100, { from: owner });
        await token.transferFrom.sendTransaction(owner, accounts[6], 95, { from: delegate });
        const remainingAllowed = (await token.allowance.call(owner, delegate)).toNumber();
        const receiverBalance = (await token.balanceOf.call(accounts[6])).toNumber();
        assert.strictEqual(remainingAllowed, 5);
        assert.strictEqual(receiverBalance, 95);
    });

    it('should not allow a delegated sender to send more than they are allowed', async () => {
        const delegate = accounts[3];
        const owner = accounts[0];
        await token.approve.sendTransaction(delegate, 1000, { from: owner });
        await assertVmException(token.transferFrom.sendTransaction, owner, accounts[5], 1100, { from: delegate });
    });

    it('should not allow an undelegated sender to send tokens from another account', async () => {
        const undelegated = accounts[2];
        await assertVmException(token.transferFrom.sendTransaction, accounts[0], accounts[3], 100, { from: undelegated });
    });

    it('should return Tontoken as the token name', async () => {
        const tokenName = await token.name.call();
        assert.strictEqual(tokenName, 'Tontoken');
    });

    it('should return TONT as the token symbol', async () => {
        const tokenSymbol = await token.symbol.call();
        assert.strictEqual(tokenSymbol, 'TONT');
    });

    it('should return 6 as the number of decimals supported', async () => {
        const tokenDecimals = (await token.decimals.call()).toNumber();
        assert.strictEqual(tokenDecimals, 6);
    });

    // TODO when voting adjustments are working
    it('should adjust the voting minimum if the median balance falls lower', async () => {});
});