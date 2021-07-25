// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IERC20.sol";
import "./VotingSystem.sol";

contract Tontoken is ERC20, VotingSystem {
    // fields to help the contract operate
    uint256 private _totalSupply;
    uint256 private allTimeTaxCollected;
    uint8 private borkTaxRateShift; // percent of each transaction to be held by contract for eventual donation
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;

    // fields to help with voting
    // struct with information about candidate
    struct BorkTaxRecipient {
        address addr;
        string name; // optional
        string description; // optional
        string website; // optional
    }
    BorkTaxRecipient[] private potentialRecipients;

    uint256 private minVoterThreshold;
    uint256 private minProposalThreshold;
    mapping(bytes32 => uint256) private lockedBorks;
    uint256 private lastVotingBlock; // block number of recent voting events
    uint256 private numBlocks7Days;
    uint256 private numBlocks1Day;

    event BorksTaxed(address indexed from, address indexed to, uint256 amount, uint256 taxesPaid);

    constructor(bool publicNet) VotingSystem(publicNet ? 256 : 8) {
        _totalSupply = 1000000000000; // initial supply of 1,000,000 Tontokens
        borkTaxRateShift = 6; // ~1.5% (+- 64 borks)
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
        require(getSendableBalance(msg.sender) >= _value && _to != address(0));
        executeTransfer(msg.sender, _to, _value);
        orchestrateVoting();
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) override public returns (bool) {
        require(allowed[msg.sender][_from] >= _value);
        require(getSendableBalance(_from) >= _value);
        require(_to != address(0));
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
        uint256 tax;
        if (from != address(this)) {
            // don't apply bork tax on tax withdrawals
            tax = applyBorkTax(value, from, to);
        }
        balances[from] -= value;
        balances[to] += value;
        emit Transfer(from, to, value);
        adjustTotalSupply(tax);
    }

    function applyBorkTax(uint256 value, address from, address to) private returns (uint256 tax) {
        uint256 taxed;
        if (value < 64) {
            taxed = 1;
        } else {
            taxed = value >> borkTaxRateShift;
        }
        balances[address(this)] += taxed;
        allTimeTaxCollected += taxed;
        emit BorksTaxed(from, to, value, taxed);
        return taxed;
    }

    function adjustTotalSupply(uint256 supplyToAdd) private {
        _totalSupply += supplyToAdd;
    }

    function collectedTaxes() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function enterVote(address vote) public {
        require(balanceOf(msg.sender) >= minVoterThreshold);
        lockBorks(msg.sender, minVoterThreshold);
        super.voteForCandidate(vote, msg.sender);
    }

    function proposeBorkTaxRecipient(address recipient) public {
        require(balanceOf(msg.sender) >= minProposalThreshold);
        require(recipient != address(0));
        lockBorks(msg.sender, minProposalThreshold);
        super.addCandidate(recipient, msg.sender);
        potentialRecipients.push(BorkTaxRecipient(recipient, "", "", ""));
    }

    function proposeBorkTaxRecipient(address recipient, string memory name, string memory description, string memory website) public {
        proposeBorkTaxRecipient(recipient);
        potentialRecipients.push(BorkTaxRecipient(recipient, name, description, website));
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
            (bool active, address winner) = super.startVoting();
            if (!active && winner != address(0)) {
                // uncontested winner
                distributeBorkTax(winner);
            }
            delete potentialRecipients;
            lastVotingBlock = block.number;
        } else if (shouldEndVoting()) {
            address winner = super.stopVoting();
            if (winner != address(0)) {
                distributeBorkTax(winner);
                delete potentialRecipients;
            }
            lastVotingBlock = block.number;
        }
    }

    function distributeBorkTax(address recipient) private {
        executeTransfer(address(this), recipient, balanceOf(address(this)));
    }

    function getVotingStatus() public view returns (VotingStatus) {
        return currentStatus;
    }

    // function donateBorks(uint256 value) public {
    //     require(value != 0);
    //     require(balances[msg.sender] >= value);
    //     executeTransfer(msg.sender, address(this), value);
    // }
}