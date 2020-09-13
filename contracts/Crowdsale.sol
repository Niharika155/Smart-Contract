pragma solidity >=0.4.22 <0.7.0;
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/utils/Pausable.sol";
import "./Token.sol";
import "./Investor.sol";

contract Crowdsale is Ownable, Pausable{
  using SafeMath for uint256;
  
  bool public active = false;
  address public wallet;
  
  uint256 public startBlock;
  uint256 public endBlock;
  
  uint256 public rate;
  uint256 public maximumDaysSupplyPercentage;
  uint256 public minimumAmountETH;

  Token private tokenContract;
  Whitelist private whitelistContract;
  uint256 public amountOfETHAsked;
  uint256 public numTokensIssued;
  
  uint256 public totalSupply;
  uint256 public softCap;
  uint256 public sold;
  
  address private updater;
  bool private finalized = false;
  
  struct Purchase {
    address owner;
    uint256 amount;
    uint256 lockup;
    bool claimed;
  }
  
  mapping(uint256 => Purchase) private purchases;
  uint256 private latestOrderId = 0;
  address private owner;
  address private treasury;
  
  struct PerDaySale {
    uint256 supply;
    uint256 soldFromUnreserved;
    uint256 reserved;
    uint256 soldFromReserved;
    mapping(address => uint256) tokenBoughtByAddress;
  }

  PerDaySale[] public statsByDay;

  event CreditsCreated(address beneficiary, uint256 amountETH, uint256 amountUSD);
  event Update(uint256 newTotalSupply, uint256 reservedTokensNextDay);
  event Activated(uint256 time);
  event Finished(uint256 time);
  event Purchase(address indexed purchaser, uint256 id, uint256 amount, uint256 purchasedAt, uint256 redeemAt);
  event Claim(address indexed purchaser, uint256 id, uint256 amount);

  modifier onlyUpdater {
    require(msg.sender == updater);
    _;
  }
  
  uint public ETHUSDPriceUINT = 1000000000000000000;
  
  function XTPresale(address token, address ethRecepient, uint256 presaleSoftCap) public {
    wallet = token;
    owner = msg.sender;
    treasury = ethRecepient;
    softCap = presaleSoftCap;
  }
  
  function Sale(
    uint256 _startBlock, 
    uint256 _endBlock,
    uint256 _rate,
    uint256 _minimumAmountETH, 
    uint256 _maximumDaysSupplyPercentage,
    address _wallet) public
  {
    require(_startBlock >= block.number);
    require(_endBlock >= _startBlock);
    require(_rate > 0);
    require(_wallet != 0x0);

    updater = msg.sender;
    startBlock = _startBlock;
    endBlock = _endBlock;
    rate = _rate;
    maximumDaysSupplyPercentage = _maximumDaysSupplyPercentage;
    minimumAmountETH = _minimumAmountETH;
    wallet = _wallet;
  }

  function setUpdater(address _updater) external onlyOwner {
    updater = _updater;
  }

  function setTokenContract(Token _tokenContract) external onlyOwner {
    tokenContract = _tokenContract;
  }

  function setWhitelistContract(Whitelist _whitelistContract) external onlyOwner {
    whitelistContract = _whitelistContract;
  }

  function currentDay() public view returns (uint) {
    return statsByDay.length;
  }

  function todaysSupply() external view returns (uint) {
    return statsByDay[currentDay()-1].supply;
  }

  function todaySold() external view returns (uint) {
    return statsByDay[currentDay()-1].soldFromUnreserved + statsByDay[currentDay()-1].soldFromReserved;
  }

  function todayReserved() external view returns (uint) {
    return statsByDay[currentDay()-1].reserved;
  }

  function boughtToday(address beneficiary) external view returns (uint) {
    return statsByDay[currentDay()-1].fuelBoughtByAddress[beneficiary];
  }

  function () public payable {
    buyToken(msg.sender);
  }

  function buyToken(address beneficiary, string _ETHprice) public payable whenNotPaused{
    require(currentDay() > 0);
    require(whitelistContract.isWhitelisted(beneficiary));
    require(tokenContract.isBalance(FinalBalance));
    require(beneficiary != 0x0);
    require(withinPeriod("30"));
    
    result = _ETHprice; // provide the current price of ETH in USD
    uint ETHContributionInWei = msg.value;
    ETHUSDPriceUINT = parseInt(result, 3); // let's use three decimal points
    uint exchangeRate = ETHUSDPriceUINT.div(ETHUSDPriceUINT);
    uint USD_Value = ETHContributionInWei.mul(ETHUSDPriceUINT);
    uint tokenFactor = 1250000000000000000 wei;
    numTokensIssued = USD_Value.mul(tokenFactor);
    amountOfETHAsked = numTokensIssued; 

    uint dayIndex = statsByDay.length-1;
    PerDaySale storage today = statsByDay[dayIndex];

    uint256 reservedTokens = whitelistContract.reservedTokens(beneficiary, dayIndex);
    uint256 alreadyBought = today.tokenBoughtByAddress[beneficiary];
    if(alreadyBought >= reservedTokens) {
      reservedTokens = 0;
    } else {
      reservedTokens = reservedTokens.sub(alreadyBought);
    }

    uint256 askedMoreThanReserved;
    uint256 useFromReserved;
    if(amountOfETHAsked > reservedTokens) {
      askedMoreThanReserved = amountOfETHAsked.sub(reservedHolos);
      useFromReserved = reservedTokens;
    } else {
      askedMoreThanReserved = 0;
      useFromReserved = amountOfETHAsked;
    }

    if(reservedTokens == 0) {
      require(msg.value >= minimumAmountETH);
    }
    
    require(lessThanMaxRatio(beneficiary, askedMoreThanReserved, today));
    require(lessThanSupply(askedMoreThanReserved, today));

    wallet.transfer(msg.value);
    tokenContract.mint(beneficiary, amountOfETHAsked);
    today.soldFromUnreserved = today.soldFromUnreserved.add(askedMoreThanReserved);
    today.soldFromReserved = today.soldFromReserved.add(useFromReserved);
    today.fuelBoughtByAddress[beneficiary] = today.fuelBoughtByAddress[beneficiary].add(amountOfETHAsked);
    CreditsCreated(beneficiary, msg.value, amountOfETHAsked);
  }

  function withinPeriod() internal constant returns (bool) {
    uint256 current = block.number;
    return current >= startBlock && current <= endBlock;
  }

  function update(uint256 newTotalSupply, uint256 reservedTokensNextDay) external onlyUpdater {
    totalSupply = newTotalSupply;
    uint256 daysSupply = newTotalSupply.sub(tokenContract.totalSupply());
    statsByDay.push(PerDaySale(daysSupply, 0, reservedTokensNextDay, 0));
    Update(newTotalSupply, reservedTokensNextDay);
  }

  function hasEnded() public constant returns (bool) {
    return block.number > endBlock;
  }
  
  function finalize() external onlyOwner {
    require(!finalized);
    require(hasEnded());
    uint256 receiptsMinted = tokenContract.totalSupply();
    uint256 shareForInvestor = receiptsMinted.div(3);
    tokenContract.mint(wallet, shareForInvestor);
    tokenContract.finishMinting();
    finalized = true;
  }

  function tokenFallback(address /* _from */, uint _value, bytes /* _data */) public {
    if (msg.sender != wallet) { revert(); }
    if (active) { revert(); }
    if (_value != softCap) { revert(); }
    active = true;
    Activated(now);
  }
  
  function lockupOf(uint256 orderId) constant public returns (uint256 timestamp) {
    return purchases[orderId].lockup;
  }

// 15% BONUS
  function firstWeek(uint start, uint daysAfter) public payable {
    if (now >= start + daysAfter * 1 days){
        uint256 priceDiv = 1875000000;
        processPurchase(priceDiv);}
  }

// 10% BONUS
  function secondWeek(uint start, uint daysAfter) public payable {
    if (now >= start + daysAfter * 7 days){
        uint256 priceDiv = 1250000000;
        processPurchase(priceDiv);}
  }

//5% BONUS
  function thirdWeek(uint start, uint daysAfter) public payable {
    if (now >= start + daysAfter * 14 days){
        uint256 priceDiv = 625000000;
        processPurchase(priceDiv);}
  }
  
 //0% BONUS
  function thirdWeek(uint start, uint daysAfter) public payable {
    if (now >= start + daysAfter * 21 days){
        uint256 priceDiv = 0;
        processPurchase(priceDiv);}
  }

  function lockupOf(uint256 orderId) constant public returns (uint256 timestamp) {
    return purchases[orderId].lockup;
  }
  
  function processPurchase(uint256 priceDiv, uint256 lockup) private {
    if (!active) { revert(); }
    if (msg.value == 0) { revert(); }
    ++latestOrderId;

    uint256 purchasedAmount = msg.value.div(priceDiv);
    if (purchasedAmount == 0) { revert(); } 
    if (purchasedAmount > hardCap - sold) { revert(); } 

    purchases[latestOrderId] = Order(msg.sender, purchasedAmount, lockup, false);
    sold += purchasedAmount;

    treasury.transfer(msg.value);
    Purchase(msg.sender, latestOrderId, purchasedAmount, now, lockup);
  }

  function redeem(uint256 orderId) public {
    if (orderId > latestOrderId) { revert(); }
    Purchase storage purchase = purchases[orderId];

    if (msg.sender != order.owner) { revert(); }
    if (now < purchase.lockup) { revert(); }
    if (purchase.claimed) { revert(); }
    purchase.claimed = true;

    ERC20 token = ERC20(wallet);
    token.transfer(order.owner, order.amount);

    Claim(Purchase.owner, orderId, order.amount);
  }

  function endPresale(address beneficiary) public {
    require(whitelistContract.isWhitelisted(beneficiary));
    if (msg.sender != beneficiary) { revert(); }
    if (!active) { revert(); }
    _end();
  }

  function _end(address beneficiary) private {
    require(whitelistContract.isWhitelisted(beneficiary));
    require(beneficiary != 0x0);
    
    if (sold < softCapCap) {
      ERC20 token = ERC20(wallet);
      token.transfer(treasury, softCap.sub(sold));
    }
    active = false;
    Finished(now);
  }
}

