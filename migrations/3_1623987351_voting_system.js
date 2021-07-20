const VotingSystem = artifacts.require("VotingSystem");

module.exports = function(deployer) {
  deployer.deploy(VotingSystem, 8);
};
