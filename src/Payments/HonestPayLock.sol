pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// downpayment %20
// success fee with downpayment, if deal cancelled refund
// add deadline, if deadline is passed and job not completed, its cancelled. % of payment refund is made accordingly

contract HonestPay is Ownable {
    enum Status {
        OfferInitiated,
        DownpaymentAvailable,
        OngoingJob,
        JobCompleted,
        JobCancelled
    }

    struct Deal {
        address employer;
        address creator;
        address paymentToken;
        uint256 totalPayment;
        uint256 deadline;
        uint256 availablePayment;
        Status status;
        uint256 employerRate;
        uint256 creatorRate;
    }

    mapping(uint256 => Deal) public dealsMapping;
    address public HonestWorkFeeCollector;
    uint256 public honestWorkFee;

    using Counters for Counters.Counter;
    Counters.Counter public dealIds;

    constructor() Ownable() {}

    function createDeal(
        address _recruiter,
        address _creator,
        address _paymentToken,
        uint256 _totalPayment,
        uint256 _deadline
    ) external payable returns (bool) {
        dealIds.increment();
        uint256 _dealId = dealIds.current();
        dealsMapping[_dealId] = Deal(
            _recruiter,
            _creator,
            _paymentToken,
            _totalPayment,
            _deadline,
            0,
            Status.OfferInitiated,0,0
        );
        if (_paymentToken == address(0)) {
            require(
                msg.value > _totalPayment,
                "employer should deposit the payment"
            );
        } else {
            IERC20 paymentToken = IERC20(_paymentToken);
            paymentToken.transferFrom(
                msg.sender,
                address(this),
                (_totalPayment)
            );
        }
    }


    function unlockPayment(uint256 _dealId, uint256 _paymentAmount) external {
        require(dealsMapping[_dealId].recruiter == msg.sender, "only recruiter can unlock payments");
        dealsMapping[_dealId].availablePayment += _paymentAmount;
    }

    function receivePayment(uint256 _dealId, uint256 _withdrawAmount) external {
        require(dealsMapping[_dealId].creator == msg.sender, "only creator can receive payments");
        require(dealsMapping[_dealId].withdrawAmount > _withdrawAmount, "desired payment is not available yet");
            address _paymentToken = dealsMapping[_dealId].paymentToken;
            if (_paymentToken == address(0)) {
            (bool payment, ) = payable(dealsMapping[_dealId].creator).call{value: _withdrawAmount}("");
            require(payment, "Failed to send payment");
        } else {
            IERC20 paymentToken = IERC20(_paymentToken);
            paymentToken.approve(dealsMapping[_dealId].creator, _withdrawAmount);
            paymentToken.transferFrom(
                address(this),
                msg.sender,
                (_totalPayment)
            );
        }
        dealsMapping[_dealId].availablePayment -= _withdrawAmount;

    }

    function additionalPayment(uint256 _dealId, uint256 _payment) external payable {
        require(dealsMapping[_dealId].creator == msg.sender, "only recruiter can add payments");
        address _paymentToken = dealsMapping[_dealId].paymentToken;
        if (_paymentToken == address(0)) {
            require(
                msg.value >= _payment,
                "recruiter should deposit the additional payment"
            );
            dealsMapping[_dealId].availablePayment += _payment;
            dealsMapping[_dealId].totalPayment += _payment;
        } else {
            IERC20 paymentToken = IERC20(_paymentToken);
            paymentToken.transferFrom(
                msg.sender,
                address(this),
                _payment);
                dealsMapping[_dealId].availablePayment += _payment;
                dealsMapping[_dealId].totalPayment += _payment;
        }
    }

        function completeJob() external {
            //require(dealsMapping[_dealId].totalPayment <=)
        }


        function getOfferHash(
        address _employer,
        address _creator,
        address _paymentToken,
        uint256 _totalAmount,
        uint256 _deadline,
        uint _nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_employer, _creator, _paymentToken, _totalAmount, _deadline, _nonce));
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }
    
    }




