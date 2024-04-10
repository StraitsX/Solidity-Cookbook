module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // deploying the DispatchReceiver contract

  const dispatchReceiverDeployment = await deploy("DispatchReceiver", {
    from: deployer,
    args: [],
    log: true,
  });

  console.log("DispatchReceiver deployed to:", dispatchReceiverDeployment.address);
};

module.exports.tags = ["DispatchReceiver"];
