pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SinglePaymentEscrow {

    IERC20 public paymentToken;
    uint256 public totalAmount;
    address public creator;
    Status public status;
    bool public nativePayment;

    enum Status {
        ContractCreated,
        DepositedPayment,
        CreatorAccepted,
        JobCompleted,
        PaymentTransferred
    }


    constructor(bool _nativePayment,address _paymentToken, uint256 _totalAmount, address _creator) {
        paymentToken = IERC20(_paymentToken);
        totalAmount = _totalAmount;
        creator = _creator;
        status = Status.ContractCreated;
        nativePayment = _nativePayment;
    }

    function deposit() external payable returns(bool) {
        if(nativePayment) {
            require(msg.value > totalAmount, "you must deposit the entire payment");
            status = Status.DepositedPayment;
        } else {
            paymentToken.transferFrom(msg.sender, address(this), totalAmount);
        }
    }



}