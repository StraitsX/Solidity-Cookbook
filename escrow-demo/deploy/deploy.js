module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy('RetailOrderEscrow', {
    from: deployer,
    args: [],
    log: true,
  });
};
