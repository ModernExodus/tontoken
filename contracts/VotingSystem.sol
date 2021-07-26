// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./UniqueKeyGenerator.sol";

contract VotingSystem is UniqueKeyGenerator {
    // fields to help with voting
    mapping(bytes32 => bool) internal isCandidate;
    
    // candidates
    mapping(address => uint256) internal votes;
    address[] internal candidates;
    
    // voters
    mapping(bytes32 => bool) internal voted;

    // proposers
    mapping(bytes32 => bool) internal addedProposal;

    VotingStatus internal currentStatus;
    enum VotingStatus { INACTIVE, PAUSE, ACTIVE }
    address internal latestWinner;
    uint256 internal numVotesHeld;
    uint16 internal maxCandidates;

    event VotingActive(uint256 votingSessionNumber);
    event VotingInactive(address winner, uint256 numVotes);
    event VotingExtended();
    event VotingPostponed(bytes32 reason);
    event VoteUncontested(address winner);
    event VoteCounted(address indexed voter, address indexed vote);

    constructor (uint16 _maxCandidates) {
        currentStatus = VotingStatus.INACTIVE;
        maxCandidates = _maxCandidates;
    }

    // START -> voting is active
    function startVoting() internal returns (bool votingActive, address uncontestedWinner) {
        assert(currentStatus == VotingStatus.INACTIVE);
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
        assert(currentStatus == VotingStatus.ACTIVE);
        (address _winner, uint256 _numVotes, bool _tied) = determineWinner();
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

    function addCandidate(address candidate, address proposer) internal {
        assert(currentStatus == VotingStatus.INACTIVE);
        require(candidates.length < maxCandidates);
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
        votes[vote]++;
        voted[voterKey] = true;
        emit VoteCounted(voter, vote);
    }

    // no-votes -> returns address(0), 0
    // tie -> returns third bool true
    function determineWinner() private view returns (address winner, uint256 numVotes, bool tie) {
        address currentLeader;
        uint256 currentMaxVotes;
        uint16 winningIndex;
        bool _tie;
        for (uint16 i = 0; i < candidates.length; i++) {
            if (votes[candidates[i]] > currentMaxVotes) {
                currentLeader = candidates[i];
                currentMaxVotes = votes[candidates[i]];
                winningIndex = i;
            }
        }
        for (uint16 i = 0; i < candidates.length; i++) {
            if (i != winningIndex && votes[candidates[i]] == currentMaxVotes) {
                _tie = true;
                break;
            }
        }
        return (currentLeader, currentMaxVotes, _tie);
    }

    function resetVotingState() private {
        for (uint16 i = 0; i < candidates.length; i++) {
            delete votes[candidates[i]];
        }
        delete candidates;
        changeKeySalt();
    }
}