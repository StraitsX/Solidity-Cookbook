// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./NoDelegateCall.sol";
import "./ERC20Helper.sol";

contract Escrow is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply, NoDelegateCall {
    using Strings for uint256;
    address public spotToken = address(0);
    bool internal initialised = false;

    constructor() ERC1155("") {}

    function initialise(address _spotToken) external onlyOwner {
        require(!initialised, "PBM: Already initialised");
        require(Address.isContract(_spotToken), "Invalid XSGD token");
        spotToken = _spotToken;

        initialised = true;
    }

    // sample metadata base URI
    string private baseURI = "https://raw.githubusercontent.com/StraitsX/NFT-Metadata/main/heroNFT2023SEP/";

    uint256 internal tokenID = 1;

    struct TokenConfig {
        uint256 spotAmount;
        string uri;
    }
    mapping(uint256 => TokenConfig) internal tokenTypes;

    function createTokenType(uint256 spotAmount, string memory tokenURI) external onlyOwner noDelegateCall {
        require(spotAmount != 0, "Spot amount is 0");
        tokenTypes[tokenID].spotAmount = spotAmount;
        tokenTypes[tokenID].uri = tokenURI;

        tokenID += 1;
    }

    struct UserBalance {
        uint256 walletBalance;
        uint256 availableBalance;
    }

    enum OrderStatus {
        PENDING,
        REDEEMED,
        CANCELLED
    }

    struct Order {
        uint256 orderValue; // how much this order cost.
        string orderId;
        address customerWallet;
        address fundDisbursementAddress; // need this to check upon redemption
        OrderStatus status;
    }

    // order id hash => order mapping
    mapping(bytes32 => Order) public orders;

    // user_address -> token_id -> UserBalance
    // token_id being the account number
    // user_address is the user’s identifier
    mapping(address => mapping(uint256 => UserBalance)) public userBalances;

    // whitelist mapping
    mapping(address => bool) public whitelist;

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "You are not authorized to call this function");
        _;
    }

    modifier orderExists(string memory orderId) {
        bytes32 orderIdHash = keccak256(abi.encodePacked(orderId));
        require(orders[orderIdHash].orderValue > 0, "Order with this ID does not exist");
        _;
    }

    function addToWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
    }

    function removeFromWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
    }

    function setURI(string memory baseUri) public onlyOwner {
        baseURI = baseUri;
    }

    function uri(uint256 token_id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(token_id), ".json"));
    }

    function mint(address userAddress, uint256 tokenId, uint256 amount, bytes memory data) public onlyOwner {
        require(userAddress != address(0), "Invalid user address");
        require(amount == 1, "Amount can only be 1");
        require(tokenTypes[tokenId].spotAmount != 0, "Invalid token id");

        UserBalance storage userBalance = userBalances[userAddress][tokenId];
        userBalance.walletBalance += tokenTypes[tokenId].spotAmount;
        userBalance.availableBalance += tokenTypes[tokenId].spotAmount;

        ERC20Helper.safeTransferFrom(spotToken, _msgSender(), address(this), tokenTypes[tokenId].spotAmount);
        emit FundsAdded(userAddress, tokenTypes[tokenId].spotAmount);
        _mint(userAddress, tokenId, amount, data);
    }

    function mintBatch(
        address userAddress,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        require(userAddress != address(0), "Invalid user address");
        require(tokenIds.length == amounts.length, "Mismatch between token IDs and amounts");
        uint256 totalSpotAmount = 0;
        // Loop over each tokenId and amount
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            require(amount == 1, "Amount can only be 1 for each token");
            require(tokenTypes[tokenId].spotAmount != 0, "Invalid token id for given tokenId");

            UserBalance storage userBalance = userBalances[userAddress][tokenId];
            userBalance.walletBalance += tokenTypes[tokenId].spotAmount;
            userBalance.availableBalance += tokenTypes[tokenId].spotAmount;
            totalSpotAmount += tokenTypes[tokenId].spotAmount;
            emit FundsAdded(userAddress, tokenTypes[tokenId].spotAmount);
        }

        ERC20Helper.safeTransferFrom(spotToken, _msgSender(), address(this), totalSpotAmount);
        _mintBatch(userAddress, tokenIds, amounts, data);
    }

    function createOrder(
        address customer_wallet_address,
        uint256 token_id,
        string memory order_id,
        uint256 order_value,
        address fund_disbursement_address
    ) external onlyWhitelisted {
        require(customer_wallet_address != address(0), "Invalid customer address");
        require(order_value > 0, "Invalid order value");
        require(fund_disbursement_address != address(0), "Invalid fund disbursement address");

        bytes32 orderIdHash = keccak256(abi.encodePacked(order_id));
        // must protect this, this ensures cannot call createOrder multiple times
        require(orders[orderIdHash].orderValue == 0, "Order with this ID already exists");

        UserBalance storage userBalance = userBalances[customer_wallet_address][token_id];
        require(userBalance.availableBalance >= order_value, "Insufficient available funds");

        orders[orderIdHash] = Order(
            order_value,
            order_id,
            customer_wallet_address,
            fund_disbursement_address,
            OrderStatus.PENDING
        );

        userBalance.availableBalance -= order_value; // can be modified to pull funds from another contract next time

        emit OrderCreated(customer_wallet_address, order_id, order_value, fund_disbursement_address);
    }

    function cancelOrder(string memory order_id, uint256 token_id) external onlyWhitelisted orderExists(order_id) {
        bytes32 orderIdHash = keccak256(abi.encodePacked(order_id));
        require(orders[orderIdHash].status != OrderStatus.CANCELLED, "This order has been canceled");
        // this check is very important, to prevent this function() from being called more than once.
        // resulting in availableBalance exceeding wallet balance.
        require(orders[orderIdHash].status == OrderStatus.PENDING, "This order is no longer pending");
        uint256 order_value = orders[orderIdHash].orderValue;

        orders[orderIdHash].status = OrderStatus.CANCELLED;

        UserBalance storage userBalance = userBalances[msg.sender][token_id];
        require(
            userBalance.walletBalance >= (userBalance.availableBalance + order_value),
            "Avail balance can never be greater than walletBalance"
        );

        userBalance.availableBalance += order_value;

        emit OrderCanceled(order_id);
    }

    function redeemOrder(
        string memory order_id,
        uint256 token_id,
        address user_wallet
    ) external onlyWhitelisted orderExists(order_id) {
        bytes32 orderIdHash = keccak256(abi.encodePacked(order_id));
        require(orders[orderIdHash].status != OrderStatus.CANCELLED, "This order has been canceled");
        // this check is very important, to prevent this function() from being called more than once.
        require(orders[orderIdHash].status == OrderStatus.PENDING, "This order is no longer pending");
        uint256 order_value = orders[orderIdHash].orderValue;
        UserBalance storage userBalance = userBalances[user_wallet][token_id];
        require(userBalance.walletBalance >= order_value, "Insufficient wallet balance");

        require(
            userBalance.walletBalance >= userBalance.availableBalance,
            "Something is wrong, availableBalance must be deducted first"
        );
        userBalance.walletBalance -= order_value;

        orders[orderIdHash].status = OrderStatus.REDEEMED;

        ERC20Helper.safeTransfer(spotToken, orders[orderIdHash].fundDisbursementAddress, order_value);

        emit OrderRedeemed(user_wallet, order_id);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    event OrderCreated(address customer, string orderId, uint256 orderValue, address fundDisbursementAddress);
    event OrderRedeemed(address customer, string orderId);
    event OrderCanceled(string orderId);
    event FundsAdded(address customer, uint256 spotAmount);
}
