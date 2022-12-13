pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SinglePaymentEscrow {

    IERC20 public paymentToken;
    uint256 public totalAmount;
    uint256 public honestWorkFee;
    address public creator;
    address public employer;
    address public HonestWorkFeeCollector;
    Status public status;
    bool public nativePayment;

    enum Status {
        ContractCreated,
        DepositedPayment,
        CreatorAccepted,
        JobCompleted,
        PaymentTransferred,
        JobCancelled
    }


    constructor(bool _nativePayment,address _paymentToken, uint256 _totalAmount, address _creator, address _employer, uint256 _honestWorkFee) {
        paymentToken = IERC20(_paymentToken);
        totalAmount = _totalAmount;
        creator = _creator;
        status = Status.ContractCreated;
        nativePayment = _nativePayment;
        employer = _employer;
        honestWorkFee = _honestWorkFee;
    }

    modifier onlyEmployer() {
        require(msg.sender == employer, "Not owner");
        _;
    }

    function deposit() external payable onlyEmployer returns(bool) {
        if(nativePayment) {
            require(msg.value > totalAmount, "you must deposit the entire payment");
            status = Status.DepositedPayment;
            return true;
        } else {
            paymentToken.transferFrom(msg.sender, address(this), totalAmount * (100 - honestWorkFee) / 100);
            paymentToken.transferFrom(msg.sender, HonestWorkFeeCollector, totalAmount * honestWorkFee / 100);
            status = Status.DepositedPayment;
            return true;
        }
    }

    function cancelJob() external onlyEmployer returns(bool) {
        require(status == Status.DepositedPayment || status == Status.CreatorAccepted);
            if(nativePayment) {
            (bool sent, ) = employer.call{value: totalAmount * (100 - honestWorkFee) / 100}("");
            require(sent, "Failed to send payment");
            return true;
        } else {
            paymentToken.transferFrom(address(this), employer, totalAmount * (100 - honestWorkFee) / 100);
            status = Status.DepositedPayment;
            return true;
        }
    }



}