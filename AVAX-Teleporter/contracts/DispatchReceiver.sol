// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import "./interfaces/ITeleporterMessenger.sol";
import "./interfaces/ITeleporterReceiver.sol";

contract DispatchReceiver is ITeleporterReceiver {
    ITeleporterMessenger public immutable teleporterMessenger =
        ITeleporterMessenger(0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf);

    string public lastMessage;

    function receiveTeleporterMessage(
        bytes32 originChainID,
        address originSenderAddress,
        bytes calldata message
    ) external {
        lastMessage = abi.decode(message, (string));
        _sendMessage(
            address(0x124eDB77c52c7fb707AeeF7695342D5B3f999d55),
            message
        );
    }

    function _sendMessage(
        address destinationAddress,
        bytes calldata message
    ) private {
        // send the message to echo subnet
        teleporterMessenger.sendCrossChainMessage(
            TeleporterMessageInput({
                destinationBlockchainID: 0x1278d1be4b987e847be3465940eb5066c4604a7fbd6e086900823597d81af4c1,
                destinationAddress: destinationAddress,
                feeInfo: TeleporterFeeInfo({
                    feeTokenAddress: address(0),
                    amount: 0
                }),
                requiredGasLimit: 3000000,
                allowedRelayerAddresses: new address[](0),
                message: message
            })
        );
    }
}
