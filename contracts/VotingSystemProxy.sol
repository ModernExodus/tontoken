// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./VotingSystem.sol";

// proxy to interact with Voting System for unit testing
contract VotingSystemProxy is VotingSystem {

    constructor () {}

    function startVotingP() public {
        super.startVoting();
    }

    function stopVotingP() public returns (address winner) {
        (, address _winner) = super.stopVoting();
        return _winner;
    }

    function postVoteCleanUp() override internal {}

    function addCandidateP(address candidate, address proposer) public {
        super.addCandidate(candidate, proposer);
    }

    function voteForCandidateP(address vote, address voter) public {
        super.voteForCandidate(vote, voter);
    }

    function getCurrentStatus() public view returns (VotingStatus) {
        return currentStatus;
    }

    function getHasVoted(address a) public view returns (bool) {
        return voted[generateKey(a)];
    }

    function hasAddedCandidate(address a) public view returns (bool) {
        return addedProposal[generateKey(a)];
    }

    function getCandidates() public view returns (address[] memory) {
        return currentVotingCycle.candidates;
    }
}