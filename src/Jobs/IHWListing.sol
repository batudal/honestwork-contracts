// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IHWListing {
    struct Payment {
        address token;
        uint256 amount;
        uint256 listingDate;
    }

    function getPayments(
        address _user
    ) external view returns (Payment[] memory);

    function getLatestPayment(
        address _user
    ) external view returns (Payment memory);

    function payForListing(address _token, uint256 _amount) external;

    function payForListingEth(
        uint256 _minTokensOut,
        uint256 _allowedDelay
    ) external payable returns (uint[] memory);

    function withdrawEarnings(address _token, uint256 _amount) external;

    function withdrawAllEarnings(address _token) external;

    function withdrawAllEarningsEth() external;

    function withdrawAllTokens() external;

    function getEthPrice(uint256 _amount) external view returns (uint);

    function updateRegistry(address _registry) external;

    function getTokenBalance() external view returns (uint);
}
