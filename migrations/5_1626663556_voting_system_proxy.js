const VotingSystemProxy = artifacts.require('VotingSystemProxy');

module.exports = function(deployer) {
  deployer.deploy(VotingSystemProxy);
};
