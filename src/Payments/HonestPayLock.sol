pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Registry/IHWRegistry.sol";
import "../HonestWorkNFT.sol";



contract HonestPayLock is Ownable {
    enum Status {
        OfferInitiated,
        JobCompleted,
        JobCancelled
    }

    struct Deal {
        address recruiter;
        address creator;
        address paymentToken;
        uint256 totalPayment;
        uint256 successFee;
        uint256 paidAmount;
        uint256 availablePayment;
        Status status;
        uint256[] recruiterRating;
        uint256[] creatorRating;
    }
    IHWRegistry public registry;
    HonestWorkNFT public hw721;

    mapping(uint256 => uint256) public additionalPaymentLimit;
    uint256 public extraPaymentLimit;
    mapping(uint256 => Deal) public dealsMapping;
    uint256 public honestWorkSuccessFee;
    address public honestWorkFeeCollector;

    using Counters for Counters.Counter;
    Counters.Counter public dealIds;

    constructor(
        address _registry,
        address _HW721,
        address _feeCollector
    ) Ownable() {
        honestWorkSuccessFee = 5;
        registry = IHWRegistry(_registry);
        hw721 = HonestWorkNFT(_HW721);
        honestWorkFeeCollector = _feeCollector;
    }

    function createDeal(
        address _recruiter,
        address _creator,
        address _paymentToken,
        uint256 _totalPayment,
        uint256 _nonce,
        bytes memory signature
    ) external payable returns (bool) {
        if (msg.sender == _recruiter) {
            require(
                verify(
                    _creator,
                    _recruiter,
                    _creator,
                    _paymentToken,
                    _totalPayment,
                    _nonce,
                    signature
                )
            );
        }

        require(
            registry.isAllowedAmount(_paymentToken, _totalPayment),
            "the token you are trying to pay with is either not whitelisted or you are exceeding the allowed amount"
        );
        dealIds.increment();
        uint256 _dealId = dealIds.current();
        uint256[] memory arr1;
        uint256[] memory arr2;
        dealsMapping[_dealId] = Deal(
            _recruiter,
            _creator,
            _paymentToken,
            _totalPayment,
            0,
            0,
            0,
            Status.OfferInitiated,
            arr1,
            arr2
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
        return true;
    }

    function unlockPayment(
        uint256 _dealId,
        uint256 _paymentAmount,
        uint256 _rating,
        uint256 _recruiterNFT
    ) external {
        require(
            _rating >= 0 && _rating <= 10,
            "rating must be between 0 and 10"
        );
        require(
            dealsMapping[_dealId].recruiter == msg.sender,
            "only recruiter can unlock payments"
        );

        dealsMapping[_dealId].availablePayment += _paymentAmount;

        require(
            dealsMapping[_dealId].totalPayment >=
                dealsMapping[_dealId].availablePayment,
            "can not go above total payment, use additional payment function pls"
        );
        dealsMapping[_dealId].creatorRating.push(_rating * 100);

        if (hw721.balanceOf(msg.sender) == 1) {
            hw721.recordGrossRevenue(_recruiterNFT, _paymentAmount);
        }
    }

    function withdrawPayment(uint256 _dealId) external {
        require(
            dealsMapping[_dealId].status == Status.OfferInitiated,
            "job should be active"
        );
        require(
            dealsMapping[_dealId].recruiter == msg.sender,
            "only recruiter can withdraw payments"
        );
        address _paymentToken = dealsMapping[_dealId].paymentToken;
        uint256 amountToBeWithdrawn = dealsMapping[_dealId].totalPayment -
            dealsMapping[_dealId].paidAmount;
        if (_paymentToken == address(0)) {
            (bool payment, ) = payable(dealsMapping[_dealId].creator).call{
                value: amountToBeWithdrawn
            }("");
            require(payment, "Failed to send payment");
        } else {
            IERC20 paymentToken = IERC20(_paymentToken);
            paymentToken.approve(
                dealsMapping[_dealId].recruiter,
                amountToBeWithdrawn
            );
            paymentToken.transferFrom(
                address(this),
                msg.sender,
                (amountToBeWithdrawn)
            );
        }

        dealsMapping[_dealId].status = Status.JobCancelled;
    }

    function claimPayment(
        uint256 _dealId,
        uint256 _withdrawAmount,
        uint256 _rating,
        uint256 _creatorNFT
    ) external {
        require(
            _rating >= 0 && _rating <= 10,
            "rating must be between 0 and 10"
        );
        require(
            dealsMapping[_dealId].creator == msg.sender,
            "only creator can receive payments"
        );
        require(
            dealsMapping[_dealId].availablePayment >= _withdrawAmount,
            "desired payment is not available yet"
        );
        address _paymentToken = dealsMapping[_dealId].paymentToken;
        dealsMapping[_dealId].paidAmount += _withdrawAmount;
        dealsMapping[_dealId].availablePayment -= _withdrawAmount;
        dealsMapping[_dealId].recruiterRating.push(_rating * 100);
        dealsMapping[_dealId].successFee +=
            (_withdrawAmount * honestWorkSuccessFee) /
            100;
        if (_paymentToken == address(0)) {
            (bool payment, ) = payable(dealsMapping[_dealId].creator).call{
                value: (_withdrawAmount * (100 - honestWorkSuccessFee)) / 100
            }("");
            require(payment, "Failed to send payment");
            (bool successFee, ) = payable(honestWorkFeeCollector).call{
                value: (_withdrawAmount * honestWorkSuccessFee) / 100
            }("");
            require(successFee, "Failed to send payment");
        } else {
            IERC20 paymentToken = IERC20(_paymentToken);
            paymentToken.approve(
                dealsMapping[_dealId].creator,
                (_withdrawAmount * (100 - honestWorkSuccessFee)) / 100
            );
            paymentToken.transferFrom(
                address(this),
                msg.sender,
                ((_withdrawAmount * (100 - honestWorkSuccessFee)) / 100)
            );
        }
        if (hw721.balanceOf(msg.sender) == 1) {
            hw721.recordGrossRevenue(_creatorNFT, _withdrawAmount);
        }
        if (
            dealsMapping[_dealId].paidAmount >=
            dealsMapping[_dealId].totalPayment
        ) {
            dealsMapping[_dealId].status = Status.JobCompleted;
        }
    }

    function additionalPayment(
        uint256 _dealId,
        uint256 _payment,
        uint256 _recruiterNFT,
        uint256 _rating
    ) external payable {
        require(
            _rating >= 0 && _rating <= 10,
            "rating must be between 0 and 10"
        );
        require(
            additionalPaymentLimit[_dealId] <= extraPaymentLimit,
            "you can not make more than 3 additional payments"
        );
        require(
            dealsMapping[_dealId].status == Status.OfferInitiated,
            "job should be active"
        );
        require(
            dealsMapping[_dealId].recruiter == msg.sender,
            "only recruiter can add payments"
        );
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
            paymentToken.transferFrom(msg.sender, address(this), _payment);
            dealsMapping[_dealId].availablePayment += _payment;
            dealsMapping[_dealId].totalPayment += _payment;
        }

        if (hw721.balanceOf(msg.sender) == 1) {
            hw721.recordGrossRevenue(_recruiterNFT, _payment);
        }

        additionalPaymentLimit[_dealId] += 1;
        dealsMapping[_dealId].creatorRating.push(_rating * 100);
    }

    function getOfferHash(
        address _employer,
        address _creator,
        address _paymentToken,
        uint256 _totalAmount,
        uint256 _nonce
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _employer,
                    _creator,
                    _paymentToken,
                    _totalAmount,
                    _nonce
                )
            );
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function verify(
        address _signer,
        address _recruiter,
        address _creator,
        address _paymentToken,
        uint256 _totalAmount,
        uint256 _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 messageHash = getOfferHash(
            _recruiter,
            _creator,
            _paymentToken,
            _totalAmount,
            _nonce
        );
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    //Getters

    function getDeal(uint256 _dealId) external view returns (Deal memory) {
        return dealsMapping[_dealId];
    }

    function getCreator(uint256 _dealId) external view returns (address) {
        return dealsMapping[_dealId].creator;
    }

    function getRecruiter(uint256 _dealId) external view returns (address) {
        return dealsMapping[_dealId].recruiter;
    }

    function getPaymentToken(uint256 _dealId) external view returns (address) {
        return dealsMapping[_dealId].paymentToken;
    }

    function getPaidAmount(uint256 _dealId) external view returns (uint256) {
        return dealsMapping[_dealId].paidAmount;
    }

    function getAvailablePayment(uint256 _dealId)
        external
        view
        returns (uint256)
    {
        return dealsMapping[_dealId].availablePayment;
    }

    function getJobCompletionRate(uint256 _dealId)
        external
        view
        returns (uint256)
    {
        return ((dealsMapping[_dealId].paidAmount * 100) /
            dealsMapping[_dealId].totalPayment);
    }


    function getRecruiterRating(uint256 _dealId)
        external
        view
        returns (uint256[] memory)
    {
        return (dealsMapping[_dealId].recruiterRating);
    }

    function getCreatorRating(uint256 _dealId)
        external
        view
        returns (uint256[] memory)
    {
        return (dealsMapping[_dealId].creatorRating);
    }

    function getAvgCreatorRating(uint256 _dealId)
        external
        view
        returns (uint256)
    {
        uint256 sum;
        for (
            uint256 i = 0;
            i <= dealsMapping[_dealId].creatorRating.length;
            i++
        ) {
            sum += dealsMapping[_dealId].creatorRating[i];
        }
        return (sum / dealsMapping[_dealId].creatorRating.length);
    }

    function getAvgRecruiterRating(uint256 _dealId)
        external
        view
        returns (uint256)
    {
        uint256 sum;
        for (
            uint256 i = 0;
            i <= dealsMapping[_dealId].recruiterRating.length;
            i++
        ) {
            sum += dealsMapping[_dealId].recruiterRating[i];
        }
        return (sum / dealsMapping[_dealId].recruiterRating.length);
    }

    function getTotalSuccessFee()
        external
        view
        returns (uint256 totalSuccessFee)
    {
        for (uint256 i = 1; i <= dealIds.current(); i++) {
            totalSuccessFee += dealsMapping[i].successFee;
        }
    }

    // admin functions

    function changeSuccessFee(uint256 _fee) external onlyOwner {
        honestWorkSuccessFee = _fee;
    }

    function changeFeeCollectorAddress(address _collector) external onlyOwner {
        honestWorkFeeCollector = _collector;
    }

    function changeRegistry(IHWRegistry _registry) external onlyOwner {
        registry = _registry;
    }

    function claimSuccessFee(uint256 _dealId, address _feeCollector)
        external
        onlyOwner
    {
        IERC20 paymentToken = IERC20(dealsMapping[_dealId].paymentToken);
        paymentToken.transfer(_feeCollector, dealsMapping[_dealId].successFee);
    }

    function claimSuccessFeeAll(address _feeCollector) external onlyOwner {
        for (uint256 i = 1; i <= dealIds.current(); i++) {
            uint256 successFee = dealsMapping[i].successFee;
            IERC20 paymentToken = IERC20(dealsMapping[i].paymentToken);
            paymentToken.transfer(_feeCollector, successFee);
        }
    }

    function changeExtraPaymentLimit(uint256 _limit) external onlyOwner {
        extraPaymentLimit = _limit;
    }
}
