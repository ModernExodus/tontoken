// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity ^0.8.4;

contract VotingSystem {
    // fields to help with donation distribution and voting
    mapping(address => bool) internal isCandidate;
    
    // candidates
    mapping(address => uint128) internal votes;
    address[] internal candidates;
    
    // voters
    mapping(address => bool) internal voted;
    address[] internal voters;

    // proposers
    mapping(address => bool) internal addedProposal;
    address[] internal proposers;

    VotingStatus internal currentStatus;
    enum VotingStatus { INACTIVE, PAUSE, ACTIVE }
    address internal latestWinner;
    uint256 internal numVotesHeld;

    event VotingActive(uint256 votingSessionNumber);
    event VotingInactive(address winner, uint128 numVotes);
    event VotingPostponed(bytes32 reason);
    event VoteUncontested(address winner);
    event VoteCounted(address indexed voter, address indexed vote);

    constructor () {
        currentStatus = VotingStatus.INACTIVE;
    }

    // START -> voting is active
    function startVoting() internal returns (bool votingActive, address uncontestedWinner) {
        if (candidates.length != 0 && candidates.length > 1) {
            currentStatus = VotingStatus.ACTIVE;
            numVotesHeld++;
            emit VotingActive(numVotesHeld);
            return (true, address(0));
        }
        if (candidates.length == 1) {
            numVotesHeld++;
            latestWinner = candidates[0];
            emit VoteUncontested(latestWinner);
            resetVotingState();
            return (false, latestWinner);
        }
        emit VotingPostponed("No candidates");
        return (false, address(0));
    }

    // INACTIVE -> voting is over, winner is determined, and options are reset
    function stopVoting() internal returns (address winner) {
        require(currentStatus == VotingStatus.ACTIVE);
        currentStatus = VotingStatus.INACTIVE;
        (address _winner, uint128 _numVotes, bool _tied) = determineWinner();
        if (_winner == address(0)) {
            emit VotingPostponed("No votes cast");
            return address(0);
        }
        if (_tied) {
            emit VotingPostponed("Voting resulted in tie");
            resetVoteCount();
            return address(0);
        }
        emit VotingInactive(_winner, _numVotes);
        latestWinner = _winner;
        resetVotingState();
        return _winner;
    }

    function addCandidate(address candidate, address proposer) public {
        require(currentStatus == VotingStatus.INACTIVE && !addedProposal[proposer] && !isCandidate[candidate]);
        isCandidate[candidate] = true;
        addedProposal[proposer] = true;
        candidates.push(candidate);
        proposers.push(proposer);
    }

    function voteForCandidate(address vote, address voter) public {
        require(currentStatus == VotingStatus.ACTIVE && !voted[voter] && isCandidate[vote]);
        votes[vote]++;
        voted[voter] = true;
        voters.push(voter);
        emit VoteCounted(voter, vote);
    }

    // no-votes -> returns address(0), 0
    // tie -> returns third bool true
    function determineWinner() private view returns (address winner, uint128 numVotes, bool tie) {
        address currentLeader;
        uint128 currentMaxVotes;
        uint32 winningIndex;
        bool _tie;
        for (uint32 i = 0; i < candidates.length; i++) {
            if (votes[candidates[i]] > currentMaxVotes) {
                currentLeader = candidates[i];
                currentMaxVotes = votes[candidates[i]];
                winningIndex = i;
            }
        }
        for (uint32 i = 0; i < candidates.length; i++) {
            if (i != winningIndex && votes[candidates[i]] == currentMaxVotes) {
                _tie = true;
                break;
            }
        }
        return (currentLeader, currentMaxVotes, _tie);
    }

    function resetVotingState() private {
        for (uint32 i = 0; i < candidates.length; i++) {
            delete votes[candidates[i]];
            delete isCandidate[candidates[i]];
        }
        delete candidates;
        for (uint32 i = 0; i < voters.length; i++) {
            delete voted[voters[i]];
        }
        delete voters;
        for (uint32 i = 0; i < proposers.length; i++) {
            delete addedProposal[proposers[i]];
            delete proposers[i];
        }
        delete proposers;
    }

    function resetVoteCount() private {
        for (uint32 i = 0; i < candidates.length; i++) {
            delete votes[candidates[i]];
        }
    }
}