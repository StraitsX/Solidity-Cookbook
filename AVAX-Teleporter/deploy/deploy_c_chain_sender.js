module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    // deploying the CChainSender contract

    const cChainSenderDeployment = await deploy("CChainSender", {
        from: deployer,
        args: [],
        log: true,
    });

    console.log("CChainSender deployed to:", cChainSenderDeployment.address);
}

module.exports.tags = ["CChainSender"];