// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IHWRegistry.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IPool.sol";

/// @title HonestWork Job Listing Contract
/// @author @takez0_o, @ReddKidd
/// @notice Accepts listing payments and distributes earnings
contract HWListing is Ownable {
    struct Payment {
        address token;
        uint256 amount;
        uint256 listingDate;
    }

    IHWRegistry public registry;
    IUniswapV2Router01 public router;
    IERC20 public stableCoin;
    IPool public pool;

    mapping(address => Payment[]) payments;

    constructor(
        address _registry,
        address _pool,
        address _stableCoin,
        address _router
    ) {
        registry = IHWRegistry(_registry);
        pool = IPool(_pool);
        stableCoin = IERC20(_stableCoin);
        router = IUniswapV2Router01(_router);
    }

    modifier checkWhitelist(address _token) {
        require(registry.isWhitelisted(_token), "Not whitelisted");
        _;
    }

    //-----------------//
    //  admin methods  //
    //-----------------//

    function updateRegistry(address _registry) external onlyOwner {
        registry = IHWRegistry(_registry);
    }

    function withdrawToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function withdrawToken(address _token) external onlyOwner {
        IERC20(_token).transfer(
            msg.sender,
            IERC20(_token).balanceOf(address(this))
        );
    }

    function withdrawETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawToken() external onlyOwner {
        uint256 counter = registry.counter();
        for (uint256 i = 0; i < counter; i++) {
            if (registry.getWhitelist()[i].token != address(0)) {
                IERC20(registry.getWhitelist()[i].token).transfer(
                    msg.sender,
                    IERC20(registry.getWhitelist()[i].token).balanceOf(
                        address(this)
                    )
                );
            }
        }
    }

    //--------------------//
    //  mutative methods  //
    //--------------------//

    function payForListing(
        address _token,
        uint256 _amount
    ) external checkWhitelist(_token) {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        payments[msg.sender].push(Payment(_token, _amount, block.timestamp));
        emit PaymentAdded(_token, _amount);
    }

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
        path[1] = address(stableCoin);
        uint[] memory amounts = router.swapExactETHForTokens{value: msg.value}(
            _minTokensOut,
            path,
            address(this),
            block.timestamp + _allowedDelay
        );
        emit PaymentAddedETH(msg.value);
        return amounts;
    }

    //----------------//
    //  view methods  //
    //----------------//

    function getPayments(
        address _user
    ) external view returns (Payment[] memory) {
        return payments[_user];
    }

    function getLatestPayment(
        address _user
    ) external view returns (Payment memory) {
        return payments[_user][payments[_user].length - 1];
    }

    function getTokenBalance() external view returns (uint) {
        return stableCoin.balanceOf(address(this));
    }

    function getEthPrice(uint256 _amount) internal view returns (uint) {
        uint256 reserve1;
        uint256 reserve2;
        (reserve1, reserve2, ) = pool.getReserves();
        return router.quote(_amount, reserve1, reserve2);
    }

    event PaymentAdded(address indexed _token, uint256 _amount);
    event PaymentAddedETH(uint256 _amount);
}
