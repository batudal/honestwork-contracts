// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/utils/MockToken.sol";
import "../src/StarterNFT.sol";

contract StarterNFTTest is Test {
    string public baseuri = "https://api.honestwork.app/metadata/starter/";
    string public single_asset_uri =
        "https://api.honestwork.app/metadata/starter/1";
    MockToken public mocktoken;
    StarterNFT public starterNFT;
    address public zero = 0x0000000000000000000000000000000000000000;
    uint256 public mock_amount = 50000 ether;
    uint256 public basefee = 10000000;

    function setUp() public {
        mocktoken = new MockToken("MCK", "MOCK");
        assertEq(mocktoken.balanceOf(address(this)), mock_amount);
        starterNFT = new StarterNFT(baseuri, address(mocktoken), basefee);
        assertEq(starterNFT.tokenURI(42), single_asset_uri);
    }

    function testURIToggle() public {
        starterNFT.setSingleAsset(false);
        assertEq(
            starterNFT.tokenURI(42),
            "https://api.honestwork.app/metadata/starter/42"
        );
    }

    function testMint() public {
        (address token, uint256 fee) = starterNFT.payment();
        IERC20(token).approve(address(starterNFT), fee);
        starterNFT.mint();
        assertEq(starterNFT.balanceOf(address(this)), 2);
        assertEq(IERC20(token).balanceOf(address(this)), mock_amount - fee);
        assertEq(IERC20(token).balanceOf(address(starterNFT)), fee);
    }

    function testPause() public {
        starterNFT.pause();
        (, uint256 fee) = starterNFT.payment();
        mocktoken.approve(address(starterNFT), fee);
        vm.expectRevert();
        starterNFT.mint();
    }

    function testWithdraw() public {
        (, uint256 fee) = starterNFT.payment();
        mocktoken.approve(address(starterNFT), fee);
        starterNFT.mint();
        starterNFT.withdraw(address(mocktoken), fee);
        assertEq(mocktoken.balanceOf(address(starterNFT)), 0);
        assertEq(mocktoken.balanceOf(address(this)), mock_amount);
        mocktoken.approve(address(starterNFT), fee);
        starterNFT.mint();
        starterNFT.withdraw(address(mocktoken));
        assertEq(mocktoken.balanceOf(address(starterNFT)), 0);
        assertEq(mocktoken.balanceOf(address(this)), mock_amount);
        mocktoken.approve(address(starterNFT), fee);
        starterNFT.mint();
        starterNFT.withdraw();
        assertEq(mocktoken.balanceOf(address(starterNFT)), 0);
        assertEq(mocktoken.balanceOf(address(this)), mock_amount);
    }
}
