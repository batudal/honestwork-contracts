// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "../Registry/IHWRegistry.sol";
import "../utils/IUniswapV2Router01.sol";
import "../utils/IPool.sol";

/// @title HonestWork Job Listing Contract
/// @author @takez0_o, @ReddKidd
/// @notice Accepts listing payments and distributes earnings
contract HWListing is Ownable {
    struct Payment {
        address token;
        uint256 amount;
        uint256 listingDate;
    }

    // todo: move router,busd,pool to constructor and add a setter function
    IHWRegistry public registry;
    IUniswapV2Router01 public router =
        IUniswapV2Router01(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    // todo: don't use chain specific name
    IERC20 public busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IPool public pool = IPool(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16);

    mapping(address => Payment[]) payments;

    constructor(address _registry) {
        registry = IHWRegistry(_registry);
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

    function withdrawEarnings(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function withdrawAllEarnings(address _token) external onlyOwner {
        IERC20(_token).transfer(
            msg.sender,
            IERC20(_token).balanceOf(address(this))
        );
    }

    function withdrawAllEarningsEth() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

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

    function getEthPrice(uint256 _amount) external view returns (uint) {
        uint256 reserve1;
        uint256 reserve2;
        (reserve1, reserve2, ) = pool.getReserves();
        return router.quote(_amount, reserve1, reserve2);
    }

    function getTokenBalance() external view returns (uint) {
        return busd.balanceOf(address(this));
    }

    event PaymentAdded(address indexed _token, uint256 _amount);
    event PaymentAddedETH(uint256 _amount);
}
