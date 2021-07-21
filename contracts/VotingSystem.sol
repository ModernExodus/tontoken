// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
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

    // no-votes -> returns address(0), 0
    // tie -> returns third bool true
    function determineWinner() private view returns (address winner, uint256 numVotes, bool tie) {
        return (currentLeader, currentLeaderVotes, currentlyTied);
    }

    function resetVotingState() private {
        delete candidates;
        delete currentLeader;
        delete currentLeaderVotes;
        delete currentlyTied;
        changeKeySalt();
    }
}