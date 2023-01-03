pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Registry/IHWRegistry.sol";

//should I add a NFT check to create deal?
//how should the job be complted or cancelled?
//if we do not bind nfts with ratings, rating system becomes bypassable. 

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
        uint256 paidAmount;
        uint256 deadline;
        uint256 availablePayment;
        Status status;
        uint256[] recruiterRating;
        uint256[] creatorRating;
    }
    IHWRegistry public registry;
    mapping(uint256 => Deal) public dealsMapping;
    uint256 public honestWorkSuccessFee;

    using Counters for Counters.Counter;
    Counters.Counter public dealIds;

    constructor(address _Registry) Ownable() {
        honestWorkSuccessFee = 5;
        registry = IHWRegistry(_Registry);
    }

    function createDeal(
        address _recruiter,
        address _creator,
        address _paymentToken,
        uint256 _totalPayment,
        uint256 _deadline,
        uint256 _nonce,
        bytes memory signature
    ) external payable returns (bool) {
        if(msg.sender == _recruiter) {
            require(verify(_creator, _recruiter, _creator, _paymentToken, _totalPayment, _deadline, _nonce, signature));
        }

        require(registry.isAllowedAmount(_paymentToken, _totalPayment), "the token you are trying to pay with is either not whitelisted or you are exceeding the allowed amount");
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
            _deadline,
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

    function unlockPayment(uint256 _dealId, uint256 _paymentAmount, uint256 _rating) external {
        require(
            dealsMapping[_dealId].recruiter == msg.sender,
            "only recruiter can unlock payments"
        );

        dealsMapping[_dealId].availablePayment += _paymentAmount;

        require(
            dealsMapping[_dealId].totalPayment >= dealsMapping[_dealId].availablePayment,
            "can not go above total payment, use additional payment function pls"
        );
        dealsMapping[_dealId].creatorRating.push(_rating);
        
        
    }

    function withdrawPayment(uint256 _dealId) external {
        require(dealsMapping[_dealId].status == Status.OfferInitiated, "job should be active");
        require(dealsMapping[_dealId].recruiter == msg.sender, "only recruiter can withdraw payments");
        address _paymentToken = dealsMapping[_dealId].paymentToken;
        uint256 amountToBeWithdrawn = dealsMapping[_dealId].totalPayment - dealsMapping[_dealId].paidAmount;
        if (_paymentToken == address(0)) {
            (bool payment, ) = payable(dealsMapping[_dealId].creator).call{value: amountToBeWithdrawn}("");
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

    function receivePayment(uint256 _dealId, uint256 _withdrawAmount, uint256 _rating) external {
        require(dealsMapping[_dealId].creator == msg.sender, "only creator can receive payments");
        require(dealsMapping[_dealId].availablePayment >= _withdrawAmount, "desired payment is not available yet");
            address _paymentToken = dealsMapping[_dealId].paymentToken;
            dealsMapping[_dealId].paidAmount += _withdrawAmount;
            dealsMapping[_dealId].availablePayment -= _withdrawAmount;
            dealsMapping[_dealId].recruiterRating.push(_rating);
            if (_paymentToken == address(0)) {
            (bool payment, ) = payable(dealsMapping[_dealId].creator).call{value: _withdrawAmount}("");
            require(payment, "Failed to send payment");
        } else {
            IERC20 paymentToken = IERC20(_paymentToken);
            paymentToken.approve(
                dealsMapping[_dealId].creator,
                _withdrawAmount
            );
            paymentToken.transferFrom(
                address(this),
                msg.sender,
                (_withdrawAmount)
            );
        }


        if(dealsMapping[_dealId].paidAmount >= dealsMapping[_dealId].totalPayment) {
            dealsMapping[_dealId].status = Status.JobCompleted;
        }
    }

    function additionalPayment(
        uint256 _dealId,
        uint256 _payment
    ) external payable {
        require(dealsMapping[_dealId].status == Status.OfferInitiated, "job should be active");
        require(
            dealsMapping[_dealId].creator == msg.sender,
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
    }

    function getOfferHash(
        address _employer,
        address _creator,
        address _paymentToken,
        uint256 _totalAmount,
        uint256 _deadline,
        uint _nonce
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _employer,
                    _creator,
                    _paymentToken,
                    _totalAmount,
                    _deadline,
                    _nonce
                )
            );
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) internal pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
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
        uint256 _deadline,
        uint _nonce,
        bytes memory signature
    ) internal pure returns (bool) {
        bytes32 messageHash = getOfferHash(_recruiter, _creator, _paymentToken, _totalAmount, _deadline, _nonce);
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
    
    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {

            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    
    }

}




