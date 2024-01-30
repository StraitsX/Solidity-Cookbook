pragma solidity ^0.8.0;

contract Wallet {
    address public owner;
    // For this one, eventually it will be user_address -> token_id -> UserBalance
    // token_id being the account number
    // user_address is the user’s identifier
    mapping(address => UserBalance) public userBalances;
    mapping(address => bool) public whitelist;
    mapping(bytes32 => bool) public canceledOrders;

    struct UserBalance {
        uint256 walletBalance;
        uint256 availableBalance;
    }

    struct Order {
        address customerWallet;
        string orderId;
        uint256 orderValue;
        address fundDisbursementAddress;
    }

    mapping(bytes32 => Order) public orders;
    // this is needed so that can loop through and 
    // cancel all pending order, to refund the user's avail balance
    bytes32[] public pendingOrderIds; 

    // todo change all msg.sender to _msgSender() 
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "You are not authorized to call this function");
        _;
    }

    modifier orderNotCanceled(bytes32 orderId) {
        require(!canceledOrders[orderId], "This order has been canceled");
        _;
    }

    modifier orderExists(string memory order_id) {
        bytes32 orderIdHash = keccak256(abi.encodePacked(order_id));
        require(orders[orderIdHash].orderValue > 0, "Order with this ID does not exist");
        _;
    }

    // eventually this should be ERC1155 setApproval() to allow the caller to pull money from
    // the user. we wanna do this, so that in the future when the funds is not in the same contract
    // ie: XSGD, the flow wont change much.
    function addToWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
    }

    function removeFromWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
    }

    // eventually delete this, and use mint() instead as part of the PBM paradigm.
    function addFunds(address userAddress, uint256 amount) external onlyOwner {
        require(userAddress != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");

        UserBalance storage userBalance = userBalances[userAddress];
        userBalance.walletBalance += amount;
        userBalance.availableBalance += amount;

        emit FundsAdded(userAddress, amount);
    }

    function createOrder(address customer_wallet_address, string memory order_id, uint256 order_value, address fund_disbursement_address) external onlyWhitelisted {
        require(customer_wallet_address != address(0), "Invalid customer address");
        require(order_value > 0, "Invalid order value"); 
        require(fund_disbursement_address != address(0), "Invalid fund disbursement address");

        bytes32 orderIdHash = keccak256(abi.encodePacked(order_id));
        // must protect this, this ensures cannot call createOrder multiple times
        require(orders[orderIdHash].orderValue == 0, "Order with this ID already exists");
        require(!canceledOrders[orderIdHash], "This order has been canceled");

        UserBalance storage userBalance = userBalances[customer_wallet_address];
        require(userBalance.availableBalance >= order_value, "Insufficient available funds");

        orders[orderIdHash] = Order(customer_wallet_address, order_id, order_value, fund_disbursement_address);
        pendingOrderIds.push(orderIdHash);

        userBalance.availableBalance -= order_value; // can be modified to pull funds from another contract next time
        canceledOrders[orderIdHash] = false;

        emit OrderCreated(customer_wallet_address, order_id, order_value, fund_disbursement_address);
    }

    function redeemOrder(string memory order_id) external onlyWhitelisted orderExists orderNotCanceled(keccak256(abi.encodePacked(order_id)))) {
        bytes32 orderIdHash = keccak256(abi.encodePacked(order_id));
        require(canceledOrders[orderIdHash] == false, "This order has been canceled");
        // this check is very important, to prevent this function() from being called more than once.
        require(isOrderPending(order_id), "This order is no longer pending");

        UserBalance storage userBalance = userBalances[msg.sender];
        uint256 order_value = getOrderValue(orderIdHash);
        require(userBalance.walletBalance >= order_value, "Insufficient wallet balance");

        require(userBalance.walletBalance >= userBalance.availableBalance, "Something is wrong, availableBalance must be deducted first");
        userBalance.walletBalance -= order_value;

        // Remove the redeemed order from pendingOrderIds array
        removePendingOrderId(orderIdHash);

        // todo add code to send ERC20 tokens to order.fund_disbursement_address
        // this is basically calling the PBM unwrap function.
    
        emit OrderRedeemed(msg.sender, order_id);
    }

    function cancelOrder(string memory order_id) external onlyWhitelisted orderExists orderNotCanceled(keccak256(abi.encodePacked(order_id)))) {
        // this check is very important, to prevent this function() from being called more than once.
        // resulting in availableBalance exceeding wallet balance.
        require(isOrderPending(order_id), "This order is no longer pending");

        bytes32 orderIdHash = keccak256(abi.encodePacked(order_id));
        canceledOrders[orderIdHash] = true;

        UserBalance storage userBalance = userBalances[msg.sender];
        uint256 order_value = getOrderValue(orderIdHash);
        require(userBalance.walletBalance >= (userBalance.availableBalance + order_value), "Avail balance can never be greater than walletBalance");
        
        // Remove the cancelled order from pendingOrderIds array
        removePendingOrderId(orderIdHash);
        userBalance.availableBalance += order_value;

        emit OrderCanceled(order_id);
    }

    function getOrderValue(bytes32 orderIdHash) internal view returns (uint256) {
        return orders[orderIdHash].orderValue;
    }

    // Removes an element from an array by moving the last element into its place
    function removePendingOrderId(bytes32 orderIdHash) internal {
        for (uint256 i = 0; i < pendingOrderIds.length; i++) {
            if (pendingOrderIds[i] == orderIdHash) {
                if (i != pendingOrderIds.length - 1) {
                    pendingOrderIds[i] = pendingOrderIds[pendingOrderIds.length - 1];
                }
                pendingOrderIds.pop();
                break;
            }
        }
    }
    
    // to optimise this we can keep a list of redeemed orders
    // by definition, if an order_id exists, and its not cancelled it should be in pending state
    // but to explicitly sure, we should still keep a list of orders that has been redeemed.
    // and hence if !redeemed() !cancelled() and orderExists, then its pending without having todo this loop
    // essentially achieving a state machine like structure, without using Enums and 
    // without modifying state.
    
    // might get DDOS if this list is huge, and blocks ppl from redeeming orders.
    // but then again, attacker need to spend money to ddos this.
    function isOrderPending(string memory order_id) external view returns (bool) {
        bytes32 orderIdHash = keccak256(abi.encodePacked(order_id));
        for (uint256 i = 0; i < pendingOrderIds.length; i++) {
            if (pendingOrderIds[i] == orderIdHash) {
                return true;
            }
        }
        return false;
    }

    function getPendingOrdersCount() external view returns (uint256) {
        return pendingOrderIds.length;
    }

    event OrderCreated(address customer, string orderId, uint256 orderValue, address fundDisbursementAddress);
    event OrderRedeemed(address customer, string orderId);
    event OrderCanceled(string orderId);
}
