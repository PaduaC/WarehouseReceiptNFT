const Receipt = artifacts.require("WarehouseReceipt");

module.exports = function (deployer) {
  deployer.deploy(Receipt, "Warehouse Receipt", "WHR");
};
