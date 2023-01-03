// pragma solidity 0.8.15;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";

// //should I add a NFT check to create deal?
// //how should the job be complted or cancelled?
// //if we do not bind nfts with ratings, rating system becomes bypassable. 

// contract HonestPay is Ownable {
//     enum Status {
//         OfferInitiated,
//         JobCompleted,
//         JobCancelled
//     }

//     struct Deal {
//         address recruiter;
//         address creator;
//         address paymentToken;
//         uint256 totalPayment;
//         uint256 paidAmount;
//         uint256 deadline;
//         uint256 availablePayment;
//         Status status;
//         uint256 employerRating;
//         uint256 creatorRating;
//     }

//     mapping(uint256 => Deal) public dealsMapping;
//     uint256 public honestWorkSuccessFee;

//     using Counters for Counters.Counter;
//     Counters.Counter public dealIds;

//     constructor() Ownable() {
//         honestWorkSuccessFee = 5;
//     }

//     function createDeal(
//         address _recruiter,
//         address _creator,
//         address _paymentToken,
//         uint256 _totalPayment,
//         uint256 _paidAmount,
//         uint256 _deadline,
//         uint256 _nonce,
//         bytes memory signature
//     ) external payable returns (bool) {
//         // if(msg.sender == _recruiter) {
//         //     require(verify(_creator, _recruiter, _creator, _paymentToken, _totalPayment, _deadline, _nonce, signature));
//         // }
//         dealIds.increment();
//         uint256 _dealId = dealIds.current();
//         dealsMapping[_dealId] = Deal(
//             _recruiter,
//             _creator,
//             _paymentToken,
//             _totalPayment,
//             0,
//             _deadline,
//             0,
//             Status.OfferInitiated,
//             0,
//             0
//         );
//         // if (_paymentToken == address(0)) {
//         //     require(
//         //         msg.value > _totalPayment,
//         //         "employer should deposit the payment"
//         //     );
//         // } else {
//         //     IERC20 paymentToken = IERC20(_paymentToken);
//         //     paymentToken.transferFrom(
//         //         msg.sender,
//         //         address(this),
//         //         (_totalPayment)
//         //     );
//         // }


//     }

//     function getDeals(uint256 _dealId) external view returns(Deal memory) {
//         uint256 _dealId = dealIds.current();
//         for(uint256 i = 0; i <= _dealId; i++) {
//             return dealsMapping[i];

//         }
//     }
// }
