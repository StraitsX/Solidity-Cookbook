module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // deploying the Echo receiver contract

  const echoReceiverDeployment = await deploy("EchoReceiver", {
    from: deployer,
    args: [],
    log: true,
  });

  console.log("EchoReceiver deployed to:", echoReceiverDeployment.address);
};

module.exports.tags = ["echoReceiver"];
