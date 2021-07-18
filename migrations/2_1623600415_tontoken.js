const Tontoken = artifacts.require("Tontoken");

module.exports = function(deployer) {
  deployer.deploy(Tontoken, false);
};
