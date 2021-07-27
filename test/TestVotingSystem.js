const { convertHexToAscii, assertVmException } = require('./test-utils.js');

const VotingSystem = artifacts.require('VotingSystemProxy');

contract('Voting System', async accounts => {
    let vs;

    beforeEach(async () => {
        vs = await VotingSystem.new();
    });

    it('should not start voting if there are no candidates', async () => {
        const transaction = await vs.startVotingP();
        const transactionLog = transaction.logs[0];
        const numVotesHeld = (await vs.getNumVotesHeld()).toNumber();
        assert.strictEqual(transactionLog.event, 'VotingPostponed');
        assert.strictEqual(convertHexToAscii(transactionLog.args[0]),  'No candidates');
        assert.strictEqual(numVotesHeld, 0);
    });

    it('should automatically declare a winner if there is no contest (only 1 candidate)', async () => {
        await vs.addCandidateP(accounts[1], accounts[0]);
        const transactionLog = (await vs.startVotingP()).logs[0];
        const numVotesHeld = (await vs.getNumVotesHeld()).toNumber();
        assert.strictEqual(transactionLog.event, 'VoteUncontested');
        assert.strictEqual(transactionLog.args[0], accounts[1]);
        assert.strictEqual(numVotesHeld, 1);
    });

    it('should start voting session', async () => {
        await vs.addCandidateP(accounts[0], accounts[0]);
        await vs.addCandidateP(accounts[1], accounts[1]);
        await vs.startVotingP();
        const numVotesHeld = (await vs.getNumVotesHeld()).toNumber();
        const currentStatus = (await vs.getCurrentStatus()).toNumber();
        assert.strictEqual(numVotesHeld, 1);
        assert.strictEqual(currentStatus, 2);
    });

    it('should allow an address to add a candidate for consideration', async () => {
        await vs.addCandidateP(accounts[1], accounts[0]);
        const candidateAdded = await vs.getIsCandidate(accounts[1]);
        const allCandidates = await vs.getCandidates();

        assert.ok(candidateAdded);
        assert.strictEqual(allCandidates.length, 1);
        assert.strictEqual(allCandidates[0], accounts[1]);
    });

    it('should not allow an address to add a candidate that is already added', async () => {
        await vs.addCandidateP(accounts[0], accounts[1]);
        await assertVmException(vs.addCandidateP, accounts[0], accounts[2]);
    });

    it('should not allow an address to add a candidate if the address already added a candidate', async () => {
        await vs.addCandidateP(accounts[0], accounts[1]);
        await vs.addCandidateP(accounts[1], accounts[5]);
        await assertVmException(vs.addCandidateP, accounts[2], accounts[1]);
    });

    it('should not allow candidates to be added while voting is active', async () => {
        await vs.addCandidateP(accounts[0], accounts[1]);
        await vs.addCandidateP(accounts[1], accounts[2]);
        await vs.startVotingP();
        await assertVmException(vs.addCandidateP, accounts[2], accounts[3]);
    });

    it('should not allow an address to vote if voting is inactive', async () => {
        await vs.addCandidateP(accounts[0], accounts[1]);
        assert.strictEqual((await vs.getCurrentStatus()).toNumber(), 0);
        await assertVmException(vs.voteForCandidateP, accounts[0]);
    });

    it('should allow an address to vote for a candidate', async () => {
        await vs.addCandidateP(accounts[1], accounts[0]);
        await vs.addCandidateP(accounts[2], accounts[1]);
        await vs.addCandidateP(accounts[3], accounts[4]);
        await vs.startVotingP();
        await vs.voteForCandidateP(accounts[2], accounts[5]);
        assert.strictEqual((await vs.getCurrentStatus()).toNumber(), 2);
        assert.ok(await vs.getHasVoted(accounts[5]));
    });

    it('should not allow an address to vote more than once', async () => {
        await vs.addCandidateP(accounts[0], accounts[1]);
        await vs.addCandidateP(accounts[1], accounts[2]);
        await vs.startVotingP();
        await vs.voteForCandidateP(accounts[0], accounts[1]);
        await assertVmException(vs.voteForCandidateP, accounts[1], accounts[1]);
    });

    it('should not allow an address to vote for a candidate not added', async () => {
        await vs.addCandidateP(accounts[0], accounts[1]);
        await vs.addCandidateP(accounts[1], accounts[2]);
        await vs.startVotingP();
        await assertVmException(vs.voteForCandidateP, accounts[2], accounts[3]);
    });

    it('should postpone voting if no candidates received votes', async () => {
        await vs.addCandidateP(accounts[0], accounts[1]);
        await vs.addCandidateP(accounts[1], accounts[2]);
        await vs.startVotingP();
        const transaction = await vs.stopVotingP();
        const transactionLog = transaction.logs[0];
        assert.strictEqual(transactionLog.event, 'VotingPostponed');
        assert.strictEqual(convertHexToAscii(transactionLog.args[0]), 'No votes cast');
    });

    it('should extend voting if there is a tie', async () => {
        await vs.addCandidateP(accounts[0], accounts[1]);
        await vs.addCandidateP(accounts[1], accounts[2]);
        await vs.addCandidateP(accounts[2], accounts[3]);
        await vs.startVotingP();
        await vs.voteForCandidateP(accounts[0], accounts[1]);
        await vs.voteForCandidateP(accounts[1], accounts[2]);
        await vs.voteForCandidateP(accounts[1], accounts[3]);
        await vs.voteForCandidateP(accounts[1], accounts[4]);
        await vs.voteForCandidateP(accounts[2], accounts[5]);
        await vs.voteForCandidateP(accounts[2], accounts[6]);
        await vs.voteForCandidateP(accounts[2], accounts[7]);
        await vs.voteForCandidateP(accounts[0], accounts[8]);
        let acc0Votes;
        let acc1Votes;
        let acc2Votes;
        acc0Votes = (await vs.getNumVotes(accounts[0])).toNumber();
        acc1Votes = (await vs.getNumVotes(accounts[1])).toNumber();
        acc2Votes = (await vs.getNumVotes(accounts[2])).toNumber();
        assert.strictEqual(acc0Votes, 2);
        assert.strictEqual(acc1Votes, 3);
        assert.strictEqual(acc2Votes, 3);
        const transaction = await vs.stopVotingP();
        const transactionLog = transaction.logs[0];
        assert.strictEqual(transactionLog.event, 'VotingExtended');
        acc0Votes = (await vs.getNumVotes(accounts[0])).toNumber();
        acc1Votes = (await vs.getNumVotes(accounts[1])).toNumber();
        acc2Votes = (await vs.getNumVotes(accounts[2])).toNumber();
        assert.strictEqual(acc0Votes, 2);
        assert.strictEqual(acc1Votes, 3);
        assert.strictEqual(acc2Votes, 3);
        const status = (await vs.getCurrentStatus()).toNumber();
        assert.strictEqual(status, 2);
    });

    it('should stop voting and determine a winner', async () => {
        // add candidates
        await vs.addCandidateP(accounts[0], accounts[1]);
        await vs.addCandidateP(accounts[2], accounts[3]);
        await vs.addCandidateP(accounts[4], accounts[5]);
        await vs.addCandidateP(accounts[6], accounts[8]);

        // vote for candidates
        await vs.startVotingP();
        assert.strictEqual((await vs.getCurrentStatus()).toNumber(), 2);
        await vs.voteForCandidateP(accounts[0], accounts[1]);
        await vs.voteForCandidateP(accounts[2], accounts[2]);
        await vs.voteForCandidateP(accounts[2], accounts[3]);
        await vs.voteForCandidateP(accounts[4], accounts[5]);
        await vs.voteForCandidateP(accounts[6], accounts[7]);

        // end voting
        const winnerTransactionLogs = (await vs.stopVotingP()).logs;
        assert.strictEqual(winnerTransactionLogs[0].event, 'VotingInactive');
        assert.strictEqual((await vs.getCurrentStatus()).toNumber(), 0);
        assert.strictEqual(winnerTransactionLogs[0].args.winner, accounts[2]);
        assert.strictEqual(winnerTransactionLogs[0].args.numVotes.toNumber(), 2);
    });
});