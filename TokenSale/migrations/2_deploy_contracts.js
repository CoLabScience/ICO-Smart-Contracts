var token = artifacts.require('CoLabToken');

module.exports = deployer => {
    deployer.deploy(token);
};