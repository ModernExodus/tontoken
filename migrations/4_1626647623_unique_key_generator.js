const UniqueKeyGenerator = artifacts.require('UniqueKeyGenerator');

module.exports = function(deployer) {
  deployer.deploy(UniqueKeyGenerator);
};
