pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HonestPay is Ownable {
    enum Status {
        DealInitiated,
        CreatorAccepted,
        JobCompleted,
        PaymentUnlocked,
        JobCancelled
    }

    struct Deal {
        address employer;
        address creator;
        address paymentToken;
        uint256 totalPayment;
        Status status;
    }

    mapping(uint256 => Deal) public dealsMapping;
    address public HonestWorkFeeCollector;
    uint256 public honestWorkFee;
    uint256 public jobListingFee; //REMOVE


    using Counters for Counters.Counter;
    Counters.Counter public dealIds;

    constructor() Ownable() {}

    function createDeal(
        address _employer,
        address _creator,
        address _paymentToken,
        uint256 _totalPayment
    ) external payable returns (bool) {
        dealIds.increment();
        dealsMapping[dealIds.current()] = Deal(
            _employer,
            _creator,
            _paymentToken,
            _totalPayment,
            Status.DealInitiated
        );
        if (_paymentToken == address(0)) {
            require(
                msg.value > _totalPayment,
                "employer should deposit the money first"
            );
        } else {
            IERC20 paymentToken = IERC20(_paymentToken);
            paymentToken.transferFrom(
                msg.sender,
                address(this),
                (_totalPayment * (100 - honestWorkFee)) / 100
            );
        }
    }

    function cancelDeal(uint256 _dealId) external {
        require(
            dealsMapping[_dealId].status == Status.DealInitiated ||
                dealsMapping[_dealId].status == Status.CreatorAccepted
        );
        require(
            dealsMapping[_dealId].employer == msg.sender,
            "only employer can cancel the job"
        );
        if (dealsMapping[_dealId].paymentToken != address(0)) {
            IERC20 paymentToken = IERC20(dealsMapping[_dealId].paymentToken);
            paymentToken.transferFrom(
                address(this),
                msg.sender,
                dealsMapping[_dealId].totalPayment
            );
            dealsMapping[_dealId].status = Status.JobCancelled;
        } else {
            (bool sent, ) = payable(msg.sender).call{
                value: dealsMapping[_dealId].totalPayment
            }("");
            require(sent, "Failed to send payment");
            dealsMapping[_dealId].status = Status.JobCancelled;
        }
    }

    function getPayment(uint256 _dealId) external {
        require(
            dealsMapping[_dealId].creator == msg.sender,
            "only relevant creator can call this function"
        );
        require(
            dealsMapping[_dealId].status == Status.PaymentUnlocked,
            "employer still did not unlock the payment"
        );
        if (dealsMapping[_dealId].paymentToken != address(0)) {
            IERC20 paymentToken = IERC20(dealsMapping[_dealId].paymentToken);
            paymentToken.transferFrom(
                address(this),
                msg.sender,
                (dealsMapping[_dealId].totalPayment * (100 - honestWorkFee)) /
                    100
            );
            paymentToken.transferFrom(
                address(this),
                HonestWorkFeeCollector,
                (dealsMapping[_dealId].totalPayment * honestWorkFee) / 100
            );
            dealsMapping[_dealId].status = Status.JobCompleted;
        } else {
            (bool creatorPayment, ) = payable(msg.sender).call{
                value: (dealsMapping[_dealId].totalPayment *
                    (100 - honestWorkFee)) / 100
            }("");
            require(creatorPayment, "Failed to send payment");

            (bool honestWorkFee, ) = payable(msg.sender).call{
                value: dealsMapping[_dealId].totalPayment * honestWorkFee
            }("");
            require(honestWorkFee, "Failed to send payment");
            dealsMapping[_dealId].status = Status.JobCompleted;
        }
    }

    function unlockPayment(uint256 _dealId) external {
        require(
            dealsMapping[_dealId].employer == msg.sender,
            "only relevant employer can call this function"
        );
        dealsMapping[_dealId].status = Status.PaymentUnlocked;
    }

    function changeCreator(address _newCreator, uint256 _dealId) external {
        require(
            dealsMapping[_dealId].employer == msg.sender,
            "only relevant employer can call this function"
        );
        dealsMapping[_dealId].creator = _newCreator;
        dealsMapping[_dealId].status = Status.DealInitiated;
    }

    function setJobListingFee(uint256 _newFee) external onlyOwner {
        jobListingFee = _newFee;

    }
}
