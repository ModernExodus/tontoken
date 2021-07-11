const { assertVmException, convertToTontokens, convertToBorks, mineBlocks } = require('./test-utils.js');

const Tontoken = artifacts.require("Tontoken");

contract('Tontoken', async accounts => {
    let token;
    
    beforeEach(async () => {
        token = await Tontoken.new(false);
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

    it('should not allow a delegated sender to send more than the balance of an address');

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

    it('should start voting if ~7 days worth of blocks have been mined', async () => {
        const startStatus = (await token.getVotingStatus.call()).toNumber();
        await token.transfer.sendTransaction(accounts[2], convertToBorks(50000), { from: accounts[0]});
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[1], { from: accounts[0] });
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[3], { from: accounts[2] });
        await mineBlocks(7);
        await token.transfer.sendTransaction(accounts[1], 10000, { from: accounts[0] });
        const endStatus = (await token.getVotingStatus.call()).toNumber();
        assert.strictEqual(startStatus, 0);
        assert.strictEqual(endStatus, 2);
    });

    it('should end voting if voting has been ongoing for at least ~1 day', async () => {
        const startStatus = (await token.getVotingStatus.call()).toNumber();
        await token.transfer.sendTransaction(accounts[2], convertToBorks(50000), { from: accounts[0]});
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[1], { from: accounts[0] });
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[3], { from: accounts[2] });
        await mineBlocks(7);
        await token.transfer.sendTransaction(accounts[1], 5000, { from: accounts[0] });
        const middleStatus = (await token.getVotingStatus.call()).toNumber();
        await mineBlocks(1);
        await token.transfer.sendTransaction(accounts[1], 5000, { from: accounts[0] });
        const endStatus = (await token.getVotingStatus.call()).toNumber();
        assert.strictEqual(startStatus, 0);
        assert.strictEqual(middleStatus, 2);
        assert.strictEqual(endStatus, 0);
    });

    it('should distribute the bork taxes to the uncontested winner if there was only 1 candidate', async () => {
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[1], { from: accounts[0] });
        await token.transfer.sendTransaction(accounts[2], 5000, { from: accounts[0] });
        await mineBlocks(8);
        const taxPoolBefore = (await token.balanceOf.call(token.address)).toNumber();
        await token.transfer.sendTransaction(accounts[2], 5000, { from: accounts[0] });
        const taxPoolAfter = (await token.balanceOf.call(token.address)).toNumber();
        const winnerBalance = (await token.balanceOf.call(accounts[1])).toNumber();
        assert.strictEqual(winnerBalance, taxPoolBefore * 2);
        assert.strictEqual(taxPoolAfter, 0);
    });

    it('should not distribute the bork taxes if there were no candidates', async () => {
        await token.transfer.sendTransaction(accounts[1], 5000, { from: accounts[0] });
        await mineBlocks(8);
        const taxPoolBefore = (await token.balanceOf.call(token.address)).toNumber();
        await token.transfer.sendTransaction(accounts[1], 5000, { from: accounts[0] });
        const taxPoolAfter = (await token.balanceOf.call(token.address)).toNumber();
        assert.strictEqual(taxPoolAfter, taxPoolBefore * 2);
    });

    it('should distribute the bork taxes to the winner of the voting session', async () => {
        // setup votes
        for (const account of accounts) {
            await token.transfer.sendTransaction(account, convertToBorks(50000), { from: accounts[0] });
        }
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[1], { from: accounts[0] });
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[2], { from: accounts[1] });
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[3], { from: accounts[2] });
        await token.proposeBorkTaxRecipient.sendTransaction(accounts[4], { from: accounts[3] });
        await mineBlocks(7);
        await token.transfer.sendTransaction(accounts[4], 100, { from: accounts[0] });

        // votes for account1 (1)
        await token.enterVote.sendTransaction(accounts[1], { from: accounts[0] });

        // votes for account2 (3)
        await token.enterVote.sendTransaction(accounts[2], { from: accounts[1] });
        await token.enterVote.sendTransaction(accounts[2], { from: accounts[3] });
        await token.enterVote.sendTransaction(accounts[2], { from: accounts[4] });

        // votes for account3 (1)
        await token.enterVote.sendTransaction(accounts[3], { from: accounts[5] });

        // votes for account4 (4)
        await token.enterVote.sendTransaction(accounts[4], { from: accounts[6] });
        await token.enterVote.sendTransaction(accounts[4], { from: accounts[7] });
        await token.enterVote.sendTransaction(accounts[4], { from: accounts[8] });
        await token.enterVote.sendTransaction(accounts[4], { from: accounts[9] });

        // end voting
        const taxPool = (await token.balanceOf.call(token.address)).toNumber();
        const winnerBalanceBefore = (await token.balanceOf.call(accounts[4])).toNumber();
        await token.transfer.sendTransaction(accounts[5], 64, { from: accounts[0] });
        const taxPoolAfter = (await token.balanceOf.call(token.address)).toNumber();
        const winnerBalanceAfter = (await token.balanceOf.call(accounts[4])).toNumber();
        
        // assert
        assert.strictEqual(taxPoolAfter, 0);
        assert.strictEqual(winnerBalanceAfter, winnerBalanceBefore + taxPool + 1);
    });

    it('should not distribute the bork taxes if there was a tie');

    it('should unlock all locked borks in the case of a tie');

    it('should ');
});