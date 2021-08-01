// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IERC20.sol";
import "./VotingSystem.sol";

contract Tontoken is ERC20, VotingSystem {
    // fields to help the contract operate
    uint256 private _totalSupply;
    uint256 private allTimeMatchAmount;
    uint8 private borkMatchRateShift; // percent of each transaction to be held by contract for eventual donation
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;

    // fields to help with voting
    // struct with information about candidate
    struct BorkPoolRecipient {
        address addr;
        string name; // optional
        string description; // optional
        string website; // optional
    }
    BorkPoolRecipient[] private potentialRecipients;

    uint256 private minVoterThreshold;
    uint256 private minProposalThreshold;
    mapping(bytes32 => uint256) private lockedBorks;
    uint256 private lastVotingBlock; // block number of recent voting events
    uint256 private numBlocks7Days;
    uint256 private numBlocks1Day;

    event BorksMatched(address indexed from, address indexed to, uint256 amount, uint256 matched);
    
    // constants
    string constant insufficientFundsMsg = "Insufficient funds to complete the transfer";
    string constant cannotSendToZeroMsg = "Funds cannot be burned (sent to the zero address)";
    string constant insufficientAllowanceMsg = "The allowance of the transaction sender is insufficient to complete the transfer";
    string constant zeroDonationMsg = "Donations must be greater than or equal to 1 Bork";

    constructor(bool publicNet) {
        _totalSupply = 1000000000000; // initial supply of 1,000,000 Tontokens
        borkMatchRateShift = 6; // ~1.5% (+- 64 borks)
        balances[msg.sender] = _totalSupply;
        minVoterThreshold = 10000000000; // at least 10,000 Tontokens to vote
        minProposalThreshold = 50000000000; // at least 50,000 Tontokens to propose
        lastVotingBlock = block.number;
        if (publicNet) {
            numBlocks7Days = 40320;
            numBlocks1Day = 5760;
        } else {
            numBlocks7Days = 7;
            numBlocks1Day = 1;
        }
    }

    function name() override public pure returns (string memory) {
        return "Tontoken";
    }

    function symbol() override public pure returns (string memory) {
        return "TONT";
    }

    function decimals() override public pure returns (uint8) {
        return 6;
    }

    function totalSupply() override public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) override public view returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) override public returns (bool) {
        validateTransfer(msg.sender, _to, _value);
        executeTransfer(msg.sender, _to, _value);
        orchestrateVoting();
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) override public returns (bool) {
        require(allowed[msg.sender][_from] >= _value, insufficientAllowanceMsg);
        validateTransfer(_from, _to, _value);
        allowed[msg.sender][_from] -= _value;
        executeTransfer(_from, _to, _value);
        orchestrateVoting();
        return true;
    }
    
    function approve(address _spender, uint256 _value) override public returns (bool) {
        require(_spender != address(0));
        require(balances[msg.sender] >= _value);
        if (allowed[_spender][msg.sender] != 0) {
            allowed[_spender][msg.sender] = 0;
        }
        allowed[_spender][msg.sender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) override public view returns (uint256) {
        return allowed[_spender][_owner];
    }

    function executeTransfer(address from, address to, uint256 value) private {
        uint256 matched;
        if (from != address(this)) {
            // don't apply bork match on bork pool withdrawals
            matched = applyBorkMatch(value, from, to);
        }
        balances[from] -= value;
        balances[to] += value;
        emit Transfer(from, to, value);
        mintBorks(matched);
    }

    function validateTransfer(address from, address to, uint256 value) private view {
        require(getSendableBalance(from) >= value, insufficientFundsMsg);
        require(to != address(0), cannotSendToZeroMsg);
    }

    function applyBorkMatch(uint256 value, address from, address to) private returns (uint256 matchAmt) {
        uint256 matched;
        if (value < 64) {
            matched = 1;
        } else {
            matched = value >> borkMatchRateShift;
        }
        balances[address(this)] += matched;
        allTimeMatchAmount += matched;
        emit BorksMatched(from, to, value, matched);
        return matched;
    }

    function mintBorks(uint256 numBorks) private {
        _totalSupply += numBorks;
    }

    function borkPool() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function enterVote(address vote) public {
        require(balanceOf(msg.sender) >= minVoterThreshold);
        lockBorks(msg.sender, minVoterThreshold);
        super.voteForCandidate(vote, msg.sender);
    }

    function addBorkPoolRecipient(address recipient) private {
        require(balanceOf(msg.sender) >= minProposalThreshold);
        require(recipient != address(0));
        lockBorks(msg.sender, minProposalThreshold);
        super.addCandidate(recipient, msg.sender);
    }

    function proposeBorkPoolRecipient(address recipient) public {
        addBorkPoolRecipient(recipient);
        potentialRecipients.push(BorkPoolRecipient(recipient, "", "", ""));
    }

    function proposeBorkPoolRecipient(address recipient, string memory _name, string memory description, string memory website) public {
        addBorkPoolRecipient(recipient);
        potentialRecipients.push(BorkPoolRecipient(recipient, _name, description, website));
    }

    function getLockedBorks(address owner) public view returns (uint256) {
        return lockedBorks[generateKey(owner)];
    }

    function lockBorks(address owner, uint256 toLock) private {
        lockedBorks[generateKey(owner)] += toLock;
    }

    function getSendableBalance(address owner) public view returns (uint256) {
        bytes32 generatedOwnerKey = generateKey(owner);
        if (lockedBorks[generatedOwnerKey] >= balances[owner]) {
            return 0;
        }
        return balances[owner] - lockedBorks[generatedOwnerKey];
    }

    function getVotingMinimum() public view returns (uint256) {
        return minVoterThreshold;
    }

    function getProposalMinimum() public view returns (uint256) {
        return minProposalThreshold;
    }

    // 1 block every ~15 seconds -> 40320 blocks -> ~ 7 days
    function shouldStartVoting() private view returns (bool) {
        return currentStatus == VotingStatus.INACTIVE && block.number - lastVotingBlock >= numBlocks7Days;
    }

    // 5760 blocks -> ~ 1 day
    function shouldEndVoting() private view returns (bool) {
        return currentStatus == VotingStatus.ACTIVE && block.number - lastVotingBlock >= numBlocks1Day;
    }

    // handles starting and stopping of voting sessions
    function orchestrateVoting() private {
        if (shouldStartVoting()) {
            (StartVotingOutcome outcome, address winner) = super.startVoting();
            if (outcome == StartVotingOutcome.UNCONTESTED) {
                // uncontested winner
                distributeBorkPool(winner);
                delete potentialRecipients;
            }
            lastVotingBlock = block.number;
        } else if (shouldEndVoting()) {
            (StopVotingOutcome outcome, address winner) = super.stopVoting();
            if (outcome == StopVotingOutcome.STOPPED) {
                distributeBorkPool(winner);
                delete potentialRecipients;
            }
            lastVotingBlock = block.number;
        }
    }

    function distributeBorkPool(address recipient) private {
        executeTransfer(address(this), recipient, balanceOf(address(this)));
    }

    function getVotingStatus() public view returns (VotingStatus) {
        return currentStatus;
    }

    function donate(uint256 value) public {
        require(value != 0, zeroDonationMsg);
        validateTransfer(msg.sender, address(this), value);
        executeTransfer(msg.sender, address(this), value);
    }
}