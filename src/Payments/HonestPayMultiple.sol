pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HonestPay is Ownable {
    enum Status {
        DealInitiated,
        MilestoneReached,
        MilestonePaymentWithdrawn,
        JobCompleted,
        JobCancelled
    }

    struct Deal {
        address employer;
        address creator;
        address paymentToken;
        uint256 totalPayment;
        Status status;
        uint256 milestonePayments;
        uint256 employerRate;
        uint256 creatorRate;
        uint256 paymentsMade;
        uint256 finalCreatorRating;
        uint256 finalEmployerRating;
    }

    mapping(uint256 => Deal) public dealsMapping;
    address public HonestWorkFeeCollector;
    uint256 public honestWorkFee;

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
        uint256 _dealId = dealIds.current();
        dealsMapping[_dealId] = Deal(
            _employer,
            _creator,
            _paymentToken,
            _totalPayment,
            Status.DealInitiated,
            0,
            0,
            0,0,0,0
        );
        if (_paymentToken == address(0)) {
            require(
                msg.value > _totalPayment / 3,
                "employer should deposit the downpayment"
            );
            dealsMapping[_dealId].milestonePayments += _totalPayment / 3;
        } else {
            IERC20 paymentToken = IERC20(_paymentToken);
            paymentToken.transferFrom(
                msg.sender,
                address(this),
                (_totalPayment / 3)
            );
            dealsMapping[_dealId].milestonePayments += _totalPayment / 3;
        }
    }

    function pay(
        uint256 _dealId,
        uint256 _amount,
        uint256 _rate
    ) external payable {
        Deal storage deal = dealsMapping[_dealId];
        require(_rate > 0, "rate must be bigger than zero");
        require(_rate < 100, "rate must be smaller than hundred");
        require(deal.employer == msg.sender, "only employer can pay");

        if (deal.paymentToken == address(0)) {
            require(
                msg.value > _amount,
                "amount sent should be the specified amount"
            );

            uint256 oldRate = deal.creatorRate;
            deal.creatorRate = (oldRate + _rate) / 2;
            deal.milestonePayments += _amount;
            deal.status = Status.MilestoneReached;
            deal.paymentsMade += _amount;
        } else {
            IERC20 paymentToken = IERC20(dealsMapping[_dealId].paymentToken);
            paymentToken.transferFrom(msg.sender, address(this), _amount);
            uint256 oldRate = deal.creatorRate;
            deal.creatorRate = (oldRate + _rate) / 2;
            deal.milestonePayments += _amount;
            deal.status = Status.MilestoneReached;
            deal.paymentsMade += _amount;
        }
        if (deal.paymentsMade > deal.totalPayment) {
            completeJobEmployer(_rate, _dealId);
        }
    }

    function withdrawCreator(uint256 _dealId, uint256 _rate) external {
        Deal storage deal = dealsMapping[_dealId];
        require(deal.creator == msg.sender, "only creator can withdraw");
        require(_rate > 0, "rate must be bigger than zero");
        require(_rate < 100, "rate must be smaller than hundred");
        if (deal.paymentToken == address(0)) {
            uint256 amount = deal.milestonePayments;
            deal.milestonePayments = 0;
            (bool payment, ) = payable(msg.sender).call{value: amount}("");
            require(payment, "Failed to send payment");
            uint256 oldRate = deal.employerRate;
            deal.employerRate = (oldRate + _rate) / 2;
            deal.status = Status.MilestonePaymentWithdrawn;
        } else {
            IERC20 paymentToken = IERC20(deal.paymentToken);
            uint256 amount = deal.milestonePayments;
            deal.milestonePayments = 0;
            paymentToken.transferFrom(address(this), msg.sender, amount);
            uint256 oldRate = deal.creatorRate;
            deal.creatorRate = (oldRate + _rate) / 2;
            deal.status = Status.MilestonePaymentWithdrawn;
        }
    }

    function completeJobEmployer(uint256 _rate, uint256 _dealId) internal {
        Deal storage deal = dealsMapping[_dealId];
        deal.finalCreatorRating = _rate;
    }

    function completeJobCreator(uint256 _dealId, uint256 _rate) external {
        Deal storage deal = dealsMapping[_dealId];
        require(deal.creator == msg.sender, "only creator can complete the job");
        deal.finalEmployerRating = _rate;
        deal.status = Status.JobCompleted;
    }
}
