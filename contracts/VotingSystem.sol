// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity ^0.8.4;

import "./UniqueKeyGenerator.sol";

contract VotingSystem is UniqueKeyGenerator {
    // fields to help with donation distribution and voting
    mapping(bytes32 => bool) internal isCandidate;
    
    // candidates
    mapping(address => uint128) internal votes;
    address[] internal candidates;
    
    // voters
    mapping(bytes32 => bool) internal voted;

    // proposers
    mapping(bytes32 => bool) internal addedProposal;

    VotingStatus internal currentStatus;
    enum VotingStatus { INACTIVE, PAUSE, ACTIVE }
    address internal latestWinner;
    uint256 internal numVotesHeld;

    event VotingActive(uint256 votingSessionNumber);
    event VotingInactive(address winner, uint128 numVotes);
    event VotingExtended();
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
        (address _winner, uint128 _numVotes, bool _tied) = determineWinner();
        if (_winner == address(0)) {
            currentStatus = VotingStatus.INACTIVE;
            emit VotingPostponed("No votes cast");
            return address(0);
        }
        if (_tied) {
            emit VotingExtended();
            return address(0);
        }
        currentStatus = VotingStatus.INACTIVE;
        emit VotingInactive(_winner, _numVotes);
        latestWinner = _winner;
        resetVotingState();
        return _winner;
    }

    function addCandidate(address candidate, address proposer) public {
        require(currentStatus == VotingStatus.INACTIVE);
        bytes32 proposerKey = generateKey(proposer);
        bytes32 candidateKey = generateKey(candidate);
        require(!addedProposal[proposerKey] && !isCandidate[candidateKey]);
        isCandidate[candidateKey] = true;
        addedProposal[proposerKey] = true;
        candidates.push(candidate);
    }

    function voteForCandidate(address vote, address voter) public {
        require(currentStatus == VotingStatus.ACTIVE);
        bytes32 voteKey = generateKey(vote);
        bytes32 voterKey = generateKey(voter);
        require(!voted[voterKey] && isCandidate[voteKey]);
        votes[vote]++;
        voted[voterKey] = true;
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
            delete isCandidate[generateKey(candidates[i])];
        }
        delete candidates;
        changeKeySalt();
    }
}