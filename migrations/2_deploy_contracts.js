const Token = artifacts.require("./Token.sol");
const Crowdsale = artifacts.require("./Crowdsale.sol");
const Investor = artifacts.require("./Investor.sol");

module.exports = function(deployer, network, accounts) {
  let sale, whitelist
  deployer.deploy(Token).then(() => {
    wei_to_eth = 1000000000000000000
    eth_to_usd = 1250000000
rate = wei_to_eth * eth_to_usd * 10000 * 100000
    min_wei_20_usd = web3.toWei(1, 'ether') * 20 / eth_to_usd / 100000
    blocks_in_7_days = 60*60*24*7 / 15
    return deployer.deploy(Crowdsale, web3.eth.blockNumber + 10, web3.eth.blockNumber + blocks_in_7_days, rate, min_wei_20_usd, 10, accounts[0])
  }).then(() => {
    return deployer.deploy(Investor)
  }).then(() => {
    return Crowdsale.deployed()
  }).then((s) => {
    sale = s
    return Token.deployed()
  }).then((t) => {
    token = t
    return Investor.deployed()
  }).then((w) => {
    whitelist = w
    return token.setMinter(sale.address)
  }).then(() => {
    return sale.setTokenContract(token.address)
  }).then(() => {
    return sale.setWhitelistContract(whitelist.address)
  })
};
