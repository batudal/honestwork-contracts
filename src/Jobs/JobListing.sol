// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "../Registry/IHWRegistry.sol";
import "../utils/IUniswapV2Router01.sol";
import "../utils/IPool.sol";

/// @title Job Listing Module for HonestWork
/// @author @takez0_o
/// @notice Accepts listing payments and distributes earnings.
/// @dev This contract is owned by the HonestWork contract.
/// @dev It is open-ended contract used specifically for the job listing payments.
/// @dev Imports are relative since abigen didn't want to work with my remappings. :P

// todo: multiple tokens
// polygon usdc 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
// pancake router 0x10ED43C718714eb63d5aA57B78B54704E256024E

contract JobListing is Ownable {
    struct Payment {
        address token; // 0x0 for ETH
        uint256 amount;
        uint256 listingDate;
    }

    IHWRegistry public registry;
    IUniswapV2Router01 public router =
        IUniswapV2Router01(0x10ED43C718714eb63d5aA57B78B54704E256024E); //pancake router
    IERC20 public busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); // busd
    IPool public pool = IPool(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16); // busd-bnb pool

    mapping(address => Payment[]) payments;

    constructor(address _registry) {
        registry = IHWRegistry(_registry);
    }

    /**
     * @notice  checks if the address if whitelisted.
     * @param   _token  .
     */
    modifier checkWhitelist(address _token) {
        require(registry.isWhitelisted(_token), "Not whitelisted");
        _;
    }

    /**
     * @notice  returns all payments of a user.
     * @param   _user  .
     */
    function getPaymentsOf(
        address _user
    ) external view returns (Payment[] memory) {
        return payments[_user];
    }

    /**
     * @notice  returns the latest payment of a user.
     * @param   _user  .
     */
    function getLatestPayment(
        address _user
    ) external view returns (Payment memory) {
        return payments[_user][payments[_user].length - 1];
    }

    /**
     * @notice  function to accept payments for listing.
     * @dev     receives a whitelisted token, records the user to the payments array.
     * @param   _token  .
     * @param   _amount  .
     */
    function payForListing(
        address _token,
        uint256 _amount
    ) external checkWhitelist(_token) {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        payments[msg.sender].push(Payment(_token, _amount, block.timestamp));
        emit PaymentAdded(_token, _amount);
    }

    /**
     * @notice  function to accept payments for listing with native currency of the network.
     * @dev     receives a native currency, records the user to the payments array, native currency is converted
     * to a stable coin. Busd is used as a stable coin.
     * @param   _minTokensOut  .
     * @param   _allowedDelay  .
     * @return  amounts from the router.
     */
    function payForListingEth(
        uint256 _minTokensOut,
        uint256 _allowedDelay
    ) external payable returns (uint[] memory) {
        require(msg.value > 0, "Can't pay 0 ETH");
        payments[msg.sender].push(
            Payment(address(0), msg.value, block.timestamp)
        );

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(busd);
        uint[] memory amounts = router.swapExactETHForTokens{value: msg.value}(
            _minTokensOut,
            path,
            address(this),
            block.timestamp + _allowedDelay
        );
        emit PaymentAddedETH(msg.value);
        return amounts;
    }

    /**
     * @notice  function to withdraw earnings.
     * @dev     sends the earnings to the owner.owner restriction
     * @param   _token  .
     * @param   _amount  .
     */
    function withdrawEarnings(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    /**
     * @notice  function to withdraw earnings.
     * @dev     sends all the earnings to the owner. owner restriction.
     * @param   _token  .
     */
    function withdrawAllEarnings(address _token) external onlyOwner {
        IERC20(_token).transfer(
            msg.sender,
            IERC20(_token).balanceOf(address(this))
        );
    }

    /**
     * @notice  function to withdraw remaining native currency.
     */
    function withdrawAllEarningsEth() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @notice  function to withdraw all tokens.
     * @dev     owner restriction.
     */
    function withdrawAllTokens() external onlyOwner {
        uint256 counter = registry.counter();
        for (uint256 i = 0; i < counter; i++) {
            if (registry.allWhitelisted()[i].token != address(0)) {
                IERC20(registry.allWhitelisted()[i].token).transfer(
                    msg.sender,
                    IERC20(registry.allWhitelisted()[i].token).balanceOf(
                        address(this)
                    )
                );
            }
        }
    }

    /**
     * @notice  function to get the price of bnb denominated in busd.
     * @dev     uses the router to get the price.
     * @param   _amount.
     */
    function getBnbPrice(uint256 _amount) external view returns (uint) {
        uint256 reserve1;
        uint256 reserve2;
        (reserve1, reserve2, ) = pool.getReserves();
        return router.quote(_amount, reserve1, reserve2);
    }

    /**
     * @notice  function to update the registry.
     * @dev     owner restriction.
     * @param   _registry.
     */
    function updateRegistry(address _registry) external onlyOwner {
        registry = IHWRegistry(_registry);
    }

    /**
     * @notice  function get busd balance of this contract.
     */
    function getBusdBalance() external view returns (uint) {
        return busd.balanceOf(address(this));
    }

    event PaymentAdded(address indexed _token, uint256 _amount);
    event PaymentAddedETH(uint256 _amount);
}
