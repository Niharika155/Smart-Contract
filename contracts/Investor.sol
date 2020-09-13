pragma solidity >=0.4.22 <0.7.0;
import "./openzeppelin/contracts/access/Ownable.sol";

contract Investor is Ownable {
    address public updater;
    struct KnownFunder {
    bool whitelisted;
    mapping(uint => uint256) reservedTokensPerDay;
  }

   mapping(address => KnownFunder) public knownFunders;

   event Whitelisted(address[] funders);
   event ReservedTokensSet(uint day, address[] funders, uint256[] reservedTokens);

   modifier onlyUpdater {
     require(msg.sender == updater);
     _;
  }
  function InvestorsWhitelist() public {
    updater = msg.sender;
  }
  
  function setUpdater(address new_updater) external onlyOwner {
    updater = new_updater;
  }
  
  function whitelist(address[] memory funders) external onlyUpdater {
     for (uint i = 0; i < funders.length; i++) {
         knownFunders[funders[i]].whitelisted = true;
     }
     Whitelisted(funders);
   }

  function unwhitelist(address[] memory funders) external onlyUpdater {
    for (uint i = 0; i < funders.length; i++) {
        knownFunders[funders[i]].whitelisted = false;
    }
  }

  function setReservedTokens(uint day, address[] memory funders, uint256[] memory reservedTokens) external onlyUpdater {
     for (uint i = 0; i < funders.length; i++) {
         knownFunders[funders[i]].reservedTokensPerDay[day] = reservedTokens[i];
     }
     
     ReservedTokensSet(day, funders, reservedTokens);
   }

  function isWhitelisted(address funder) external view returns (bool) {
    return knownFunders[funder].whitelisted;
  }
 
  function reservedTokens(address funder, uint day) external view returns (uint256) {
    return knownFunders[funder].reservedTokensPerDay[day];
  }
}
