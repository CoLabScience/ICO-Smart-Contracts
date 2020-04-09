pragma solidity 0.6.4;

// ----------------------------------------------------------------------------
// CoLab Science Token
//
// Deployed to : <testnet>
// Symbol      : LAB
// Name        : CoLab Token
// Total supply: 1,000,000,000
// Decimals    : 18
// ----------------------------------------------------------------------------


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }
}

contract CoLabToken {
    using SafeMath for uint;

    string public constant name = "CoLab Token TESTNET";
    string public constant symbol = "TESTLAB";

    uint8 public decimals = 18;

    uint256 _totalSupply;

    address public minter;
    address public owner;

    mapping(address=>uint256) public balances;
    mapping(address=>mapping(address=>uint256)) public allowed;

    event Transfer(address indexed From, address indexed To, uint256 Amount);
    event Approval(address indexed Owner, address indexed Spender, uint256 Amount);

    modifier onlyMinter() {
        require(msg.sender == minter, "Not a minter address");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller not owner");
        _;
    }

    constructor() public {
        // Update minter to crowdsale contract once contract is deployed
        minter = owner = msg.sender;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function transfer(address _to, uint256 _amount) public returns (bool) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool) {
        _transfer(_from, _to, _amount);
        _approve(_from, msg.sender, allowed[_from][msg.sender].sub(_amount));
        return true;
    }

    function approve(address _spender, uint256 _amount) public returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function increaseAllowance(address _spender, uint256 _amount) public returns (bool) {
        _approve(msg.sender, _spender, allowed[msg.sender][_spender].add(_amount));
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _amount) public returns (bool) {
        _approve(msg.sender, _spender, allowed[msg.sender][_spender].sub(_amount));
        return true;
    }

    function mint(address _buyer, uint256 _amount) external onlyMinter {
        require(_buyer != address(0), "Invalid buyer address");
        _totalSupply = _totalSupply.add(_amount);
        balances[_buyer] = balances[_buyer].add(_amount);
        emit Transfer(address(0), _buyer, _amount);
    }

    function updateMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function _transfer(address _from, address _to, uint256 _amount) internal {
        require(_to != address(0), "Invalid From Address : 0");
        require(_amount > 0, "Invalid Amount : 0");
        require(balanceOf(_from) >= _amount, "Insufficient Balance");
        balances[_from] = balances[_from].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Transfer(_from, _to, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "Invalid From Address : 0");
        require(_spender != address(0), "Invalid To Address : 0");
        allowed[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }
}