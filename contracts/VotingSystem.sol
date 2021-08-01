// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./UniqueKeyGenerator.sol";

contract VotingSystem is UniqueKeyGenerator {
    // fields to help with voting
    mapping(bytes32 => bool) internal isCandidate;
    
    // candidates
    address[] internal candidates;
    mapping(bytes32 => uint256) internal votes;
    address internal currentLeader;
    uint256 internal currentLeaderVotes;
    bool internal currentlyTied;

    // voters
    mapping(bytes32 => bool) internal voted;

    // proposers
    mapping(bytes32 => bool) internal addedProposal;

    VotingStatus internal currentStatus;
    enum VotingStatus { INACTIVE, PAUSE, ACTIVE }
    enum StartVotingOutcome { STARTED, UNCONTESTED, NO_CANDIDATES }
    enum StopVotingOutcome { STOPPED, NO_VOTES, TIE }
    address internal latestWinner;
    uint256 internal numVotesHeld;

    event VotingActive(uint256 votingSessionNumber);
    event VotingInactive(address winner, uint256 numVotes);
    event VotingExtended();
    event VotingPostponed(bytes32 reason);
    event VoteUncontested(address winner);
    event VoteCounted(address indexed voter, address indexed vote);

    constructor () {
        currentStatus = VotingStatus.INACTIVE;
    }

    // START -> voting is active
    function startVoting() internal returns (StartVotingOutcome outcome, address winner) {
        assert(currentStatus == VotingStatus.INACTIVE);
        if (candidates.length != 0 && candidates.length > 1) {
            currentStatus = VotingStatus.ACTIVE;
            numVotesHeld++;
            emit VotingActive(numVotesHeld);
            return (StartVotingOutcome.STARTED, address(0));
        }
        if (candidates.length == 1) {
            numVotesHeld++;
            latestWinner = candidates[0];
            emit VoteUncontested(latestWinner);
            resetVotingState();
            return (StartVotingOutcome.UNCONTESTED, latestWinner);
        }
        emit VotingPostponed("No candidates");
        return (StartVotingOutcome.NO_CANDIDATES, address(0));
    }

    // INACTIVE -> voting is over, winner is determined, and options are reset
    function stopVoting() internal returns (StopVotingOutcome outcome, address winner) {
        assert(currentStatus == VotingStatus.ACTIVE);
        if (currentLeader == address(0)) {
            currentStatus = VotingStatus.INACTIVE;
            emit VotingPostponed("No votes cast");
            return (StopVotingOutcome.NO_VOTES, address(0));
        }
        if (currentlyTied) {
            emit VotingExtended();
            return (StopVotingOutcome.TIE, address(0));
        }
        currentStatus = VotingStatus.INACTIVE;
        emit VotingInactive(currentLeader, currentLeaderVotes);
        latestWinner = currentLeader;
        resetVotingState();
        return (StopVotingOutcome.STOPPED, latestWinner);
    }

    function addCandidate(address candidate, address proposer) internal {
        assert(currentStatus == VotingStatus.INACTIVE);
        bytes32 proposerKey = generateKey(proposer);
        bytes32 candidateKey = generateKey(candidate);
        require(!addedProposal[proposerKey] && !isCandidate[candidateKey]);
        isCandidate[candidateKey] = true;
        addedProposal[proposerKey] = true;
        candidates.push(candidate);
    }

    function voteForCandidate(address vote, address voter) internal {
        assert(currentStatus == VotingStatus.ACTIVE);
        bytes32 voteKey = generateKey(vote);
        bytes32 voterKey = generateKey(voter);
        require(!voted[voterKey] && isCandidate[voteKey]);
        votes[voteKey]++;
        voted[voterKey] = true;
        adjustLeader(vote, votes[voteKey]);
        emit VoteCounted(voter, vote);
    }

    function adjustLeader(address vote, uint256 numVotes) private {
        if (numVotes == currentLeaderVotes) {
            currentlyTied = true;
        } else if (numVotes > currentLeaderVotes) {
            currentLeaderVotes = numVotes;
            currentLeader = vote;
            currentlyTied = false;
        }
    }

    function resetVotingState() private {
        delete candidates;
        delete currentLeader;
        delete currentLeaderVotes;
        delete currentlyTied;
        changeKeySalt();
    }
}