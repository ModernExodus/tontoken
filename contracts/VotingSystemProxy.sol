// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity 0.8.4;

import "./VotingSystem.sol";

// proxy to interact with Voting System for unit testing
contract VotingSystemProxy is VotingSystem {
    function startVotingP() public {
        super.startVoting();
    }

    function stopVotingP() public {
        super.stopVoting();
    }

    function getLatestWinner() public view returns (address) {
        return latestWinner;
    }

    function getNumVotesHeld() public view returns (uint256) {
        return numVotesHeld;
    }

    function getCurrentStatus() public view returns (VotingStatus) {
        return currentStatus;
    }

    function getIsCandidate(address a) public view returns (bool) {
        return isCandidate[a];
    }

    function getHasVoted(address a) public view returns (bool) {
        return voted[a];
    }

    function hasAddedCandidate(address a) public view returns (bool) {
        return addedProposal[a];
    }

    function getCandidates() public view returns (address[] memory) {
        return candidates;
    }

    function getVoters() public view returns (address[] memory) {
        return voters;
    }

    function getProposers() public view returns (address[] memory) {
        return proposers;
    }

    function getNumVotes(address a) public view returns (uint128) {
        return votes[a];
    }
}