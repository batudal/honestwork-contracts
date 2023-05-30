// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/utils/MockToken.sol";
import "../src/StarterNFT.sol";

contract StarterNFTTest is Test {
    string public baseuri = "https://api.honestwork.app/metadata/starter/";
    string public single_asset_uri =
        "https://api.honestwork.app/metadata/starter/0";
    MockToken public token;
    StarterNFT public starterNFT;
    address public zero = 0x0000000000000000000000000000000000000000;
    uint256 public mock_amount = 50000 ether;

    function setUp() public {
        token = new MockToken("MCK", "MOCK");
        assertEq(token.balanceOf(address(this)), mock_amount);
        starterNFT = new StarterNFT(baseuri, address(token));
        assertEq(starterNFT.tokenURI(42), single_asset_uri);
        address[] memory whitelist = starterNFT.getWhitelist();
        assertEq(whitelist.length, 1);
        assertEq(whitelist[0], address(token));
    }

    function testURIToggle() public {
        starterNFT.setSingleAsset(false);
        assertEq(
            starterNFT.tokenURI(42),
            "https://api.honestwork.app/metadata/starter/42"
        );
    }

    function testMint() public {
        uint256 fee = starterNFT.fee();
        token.approve(address(starterNFT), fee);
        starterNFT.mint(address(token));
        assertEq(starterNFT.balanceOf(address(this)), 1);
        assertEq(token.balanceOf(address(this)), mock_amount - fee);
        assertEq(token.balanceOf(address(starterNFT)), fee);
    }

    function testPause() public {
        starterNFT.pause();
        uint256 fee = starterNFT.fee();
        token.approve(address(starterNFT), fee);
        vm.expectRevert();
        starterNFT.mint(address(token));
    }

    function testRemoveToken() public {
        starterNFT.removeWhitelistToken(address(token));
        address[] memory whitelist = starterNFT.getWhitelist();
        assertEq(whitelist[0], zero);
    }

    function testWithdraw() public {
        uint256 fee = starterNFT.fee();
        token.approve(address(starterNFT), fee);
        starterNFT.mint(address(token));
        starterNFT.withdraw(address(token), fee);
        assertEq(token.balanceOf(address(starterNFT)), 0);
        assertEq(token.balanceOf(address(this)), mock_amount);
        token.approve(address(starterNFT), fee);
        starterNFT.mint(address(token));
        starterNFT.withdraw(address(token));
        assertEq(token.balanceOf(address(starterNFT)), 0);
        assertEq(token.balanceOf(address(this)), mock_amount);
        token.approve(address(starterNFT), fee);
        starterNFT.mint(address(token));
        starterNFT.withdraw();
        assertEq(token.balanceOf(address(starterNFT)), 0);
        assertEq(token.balanceOf(address(this)), mock_amount);
    }
}
