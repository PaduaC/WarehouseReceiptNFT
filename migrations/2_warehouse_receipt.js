const Receipt = artifacts.require("WarehouseReceipt");

module.exports = function (deployer) {
  deployer.deploy(Receipt, "Finless Warehouse NFT Protocol", "WHR");
};
