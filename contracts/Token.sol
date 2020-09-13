pragma solidity >=0.4.22 <0.7.0;
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20.sol";

contract Token is ERC20, Ownable{
    string public name = "XToken";
    string public symbol = "XT";
    uint public decimals = 4;
    uint public totalSupply = 1250000000 * 10**4;
    
    mapping(address => uint256) public balances;
    
    function Balance() {
    balances[msg.sender] = totalSupply;
    FinalBalance(balances);
    }
    
    function transfer(address _to, uint256 _value) public override whenMintingFinished returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

    function balanceOf (address tokenOwner) public view override returns (uint balance) { 
        return balances [tokenOwner]; 
    } 
    
    function transferFrom(address _from, address _to, uint256 _value) public whenMintingFinished returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

         balances[_from] = balances[_from].sub(_value);
         balances[_to] = balances[_to].add(_value);
         allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
         Transfer(_from, _to, _value);
         return true;
    }

    function approve(address _spender, uint256 _value) public whenMintingFinished returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
          allowed[msg.sender][_spender] = 0;
        } else {
          allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
    
    bool public mintingFinished = false;
    address public destroyer;
    address public minter;
    
    modifier canMint() {
        require(!mintingFinished);
        _;
    }
    
    modifier whenMintingFinished() {
        require(mintingFinished);
        _;
    }
    
    modifier onlyMinter() {
        require(msg.sender == minter);
        _;
    }
    
    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function mint(address _to, uint256 _amount) external onlyMinter canMint returns (bool) {
        require(balances[_to] + _amount > balances[_to]); 
        require(totalSupply + _amount > totalSupply);     
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(_to, _amount);
        return true;
    }

    function finishMinting() external onlyMinter returns (bool) {
        mintingFinished = true;
        MintingFinished();
        return true;
    }

    modifier onlyDestroyer() {
        require(msg.sender == destroyer);
     _;
    }

    function setDestroyer(address _destroyer) external onlyOwner {
        destroyer = _destroyer;
    }

    function burn(uint256 _amount) external onlyDestroyer {
        require(balances[destroyer] >= _amount && _amount > 0);
        balances[destroyer] = balances[destroyer].sub(_amount);
        totalSupply = totalSupply.sub(_amount);
        Burn(_amount);
    }
}
