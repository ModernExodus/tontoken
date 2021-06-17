// SPDX-License-Identifier: <SPDX-License> TODO BEFORE PUBLISHING
pragma solidity 0.8.4;

import "./IERC20.sol";

contract Tontoken is ERC20 {
    address private contractAdmin;
    uint256 private _totalSupply;
    uint256 private exchangeRate; // num wei per bork
    uint16 private borkTaxRate; // percent of each transaction to be held by contract
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;

    event WeiDonated(address indexed from, uint256 amount);
    event WeiWithdrawn(address indexed to, uint256 amount);
    event BorksTaxed(address indexed from, address indexed to, uint256 amountBeforeTax, uint256 amountAfterTax, uint256 taxesPaid);

    constructor() {
        _totalSupply = 1000000000000; // initial supply of 1000000 Tontokens (1 ETH)
        exchangeRate = 1000000; // 1000000 wei per bork (1000000 borks per Tontoken -> 1 szabo = 1 Tontoken)
        borkTaxRate = 100; // ~1-2% depending on the size of trx
        balances[msg.sender] = _totalSupply;
        contractAdmin = msg.sender;
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
        allowed[msg.sender][_from] -= _value;
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
        uint256 transferAmt;
        uint256 tax;
        if (from != address(0)) {
            // only apply bork tax on regular transactions that don't create Tontoken
            (transferAmt, tax) = applyBorkTax(value);
            emit BorksTaxed(from, to, value, transferAmt, tax);
            balances[from] -= value;
        } else {
            transferAmt = value;
        }
        balances[to] += transferAmt;
        emit Transfer(from, to, value);
    }

    function applyBorkTax(uint256 value) private returns (uint256 valueAfterTax, uint256 tax) {
        uint256 taxed;
        if (value < borkTaxRate) {
            taxed = 1;
        } else {
            taxed = value / borkTaxRate;
        }
        balances[address(this)] += taxed;
        return (value - taxed, taxed);
    }

    function collectedTaxes() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function weiToBorks() public payable {
        uint256 numBorks = convertToBorks(msg.value);
        _totalSupply += numBorks;
        executeTransfer(address(0), msg.sender, numBorks);
        emit WeiDonated(msg.sender, msg.value);
    }

    function donateBorks(uint256 value) public {
        require(value != 0);
        require(balances[msg.sender] >= value);
        executeTransfer(msg.sender, address(this), value);
    }

    function withdrawBorks() public {
        require(msg.sender == contractAdmin);
        require(balanceOf(address(this)) > 0);
        executeTransfer(address(this), contractAdmin, balanceOf(address(this)));
    }
    
    function withdrawWeiToDonate() public {
        require(msg.sender == contractAdmin);
        require(address(this).balance > 0 wei);
        address payable donater = payable(contractAdmin);
        uint256 weiToWithdraw = address(this).balance;
        donater.transfer(address(this).balance);
        emit WeiWithdrawn(contractAdmin, weiToWithdraw);
    }

    function adjustBorkTaxRate(uint16 rate) public {
        require(msg.sender == contractAdmin);
        require(rate > 0 && rate <= 100);
        borkTaxRate = rate;
    }

    // converts wei -> borks at current exchange rate
    function convertToBorks(uint256 _wei) private view returns (uint256) {
        require(_wei >= exchangeRate);
        return _wei / exchangeRate;
    }
}