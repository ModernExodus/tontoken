// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity 0.8.4;

contract VotingSystem {
    // fields to help with donation distribution and voting
    mapping(address => bool) internal isCandidate;
    
    // candidates
    mapping(address => uint128) internal votes;
    address[] private candidates;
    
    // voters
    mapping(address => bool) internal voted;
    address[] private voters;

    // proposers
    mapping(address => bool) internal addedProposal;
    address[] private proposers;

    VotingStatus internal currentStatus;
    enum VotingStatus { INACTIVE, PAUSE, ACTIVE }
    address internal latestWinner;
    uint256 private numVotesHeld;

    event VotingActive(uint256 votingSessionNumber);
    event VotingPaused();
    event VotingInactive(address winner, uint128 numVotes);
    event VotingPostponed(bytes32 reason);
    event VoteUncontested(address winner);
    event VoteCounted(address indexed voter, address indexed vote);

    constructor () {
        currentStatus = VotingStatus.INACTIVE;
    }

    // START -> voting is active
    function startVoting() public {
        if (candidates.length != 0 && candidates.length > 1) {
            currentStatus = VotingStatus.ACTIVE;
            numVotesHeld++;
            emit VotingActive(numVotesHeld);
        } else if (candidates.length == 1) {
            numVotesHeld++;
            latestWinner = candidates[0];
            emit VoteUncontested(latestWinner);
            resetVotingAddresses();
        } else {
            emit VotingPostponed("No candidates");
        }
    }

    // INACTIVE -> voting is over, winner is determined, and options are reset
    function stopVoting() public returns (address winner) {
        require(currentStatus == VotingStatus.ACTIVE);
        currentStatus = VotingStatus.INACTIVE;
        (address _winner, uint128 _numVotes) = determineWinner();
        emit VotingInactive(_winner, _numVotes);
        latestWinner = _winner;
        resetVotingAddresses();
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

    // still need to handle ties and no-vote situations
    function determineWinner() private view returns (address winner, uint128 numVotes) {
        address currentLeader;
        uint128 currentMaxVotes;
        for (uint32 i = 0; i < candidates.length; i++) {
            if (votes[candidates[i]] > currentMaxVotes) {
                currentLeader = candidates[i];
                currentMaxVotes = votes[candidates[i]];
            }
        }
        return (currentLeader, currentMaxVotes);
    }

    function resetVotingAddresses() private {
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
}