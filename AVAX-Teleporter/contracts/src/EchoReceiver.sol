// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import "./interfaces/ITeleporterMessenger.sol";
import "./interfaces/ITeleporterReceiver.sol";

contract EchoReceiver is ITeleporterReceiver {
    ITeleporterMessenger public immutable teleporterMessenger =
        ITeleporterMessenger(0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf);

    string public lastMessage;

    function receiveTeleporterMessage(
        bytes32 originChainID,
        address originSenderAddress,
        bytes calldata message
    ) external {
        lastMessage = abi.decode(message, (string));
    }
}
