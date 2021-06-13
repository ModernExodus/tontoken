// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity 0.8.4;

import "./IERC20.sol";
import "./SafeMath.sol";

contract Tontoken is ERC20 {
    using SafeMath for uint256;

    address private contractDeployer;
    uint256 private _totalSupply;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;

    constructor() {
        //for testing
        _totalSupply = 1000;
        contractDeployer = msg.sender;
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
        require(balances[msg.sender] >= _value);
        require(_to != address(0));
        executeTransfer(msg.sender, _to, _value);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) override public returns (bool) {
        require(allowed[msg.sender][_from] > 0);
        require(allowed[msg.sender][_from] >= _value);
        require(balances[_from] >= _value);
        require(_to != address(0));
        allowed[msg.sender][_from] = allowed[msg.sender][_from].subtract(_value);
        executeTransfer(_from, _to, _value);
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
        balances[from] = balances[from].subtract(value);
        balances[to] = balances[to].add(value);
        emit Transfer(from, to, value);
    }
}