// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/HWEscrow.sol";
import "../src/HonestWorkNFT.sol";
import "../src/HWRegistry.sol";
import "../src/HWListing.sol";
import "../src/utils/MockToken.sol";

contract HWListingTest is Test {
    struct Payment {
        address token; // 0x0 for ETH
        uint256 amount;
        uint256 listingDate;
    }

    HWRegistry public registry;
    HWListing public listing;
    MockToken public token;
    MockToken public token2;
    MockToken public token3;
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    function setUp() public {
        registry = new HWRegistry();
        listing = new HWListing(address(registry));
        token = new MockToken("MCK", "MOCK");
        token2 = new MockToken("MCK", "MOCK");
        token3 = new MockToken("MCK", "MOCK");

        recruiter1 = vm.addr(1);
        recruiter2 = vm.addr(2);
        creator1 = vm.addr(3);
        creator2 = vm.addr(4);
        vm.deal(recruiter1, 100 ether);
        vm.deal(recruiter2, 100 ether);
        vm.deal(creator1, 100 ether);
        vm.deal(creator2, 100 ether);

        token.transfer(address(recruiter1), 1 ether);
        token2.transfer(address(recruiter2), 2 ether);
        token3.transfer(address(creator2), 3 ether);
    }

    function testSetup() public {
        assertEq(token.balanceOf(address(deployer)), 49999 ether);
        assertEq(registry.isWhitelisted(address(token)), false);
        assertEq(token.balanceOf(address(recruiter1)), 1e18);
    }

    function testAddToWhitelist() public {
        vm.prank(deployer);
        registry.addToWhitelist(address(token), 1000 ether);
        assertEq(registry.isWhitelisted(address(token)), true);
        vm.prank(recruiter1);
        token.approve(address(listing), 2 ether);
        vm.prank(recruiter1);
        listing.payForListing(address(token), 1 ether);

        assertEq(token.balanceOf(address(recruiter1)), 0 ether);
        assertEq(token.balanceOf(address(listing)), 1 ether);
        assertEq(token.balanceOf(address(deployer)), 49999 ether);
        assertEq(token.balanceOf(address(registry)), 0 ether);
        assertEq(listing.getLatestPayment(address(recruiter1)).amount, 1 ether);
        assertEq(
            listing.getLatestPayment(address(recruiter1)).token,
            address(token)
        );
        assertEq(
            listing.getLatestPayment(address(recruiter1)).listingDate,
            block.timestamp
        );
    }

    function testWithdrawAll() public {
        vm.prank(deployer);
        registry.addToWhitelist(address(token), 1000 ether);
        registry.addToWhitelist(address(token2), 1000 ether);
        registry.addToWhitelist(address(token3), 1000 ether);
        registry.addToWhitelist(address(0), 1000 ether);
        assertEq(registry.isWhitelisted(address(token)), true);
        assertEq(registry.isWhitelisted(address(token2)), true);
        assertEq(registry.isWhitelisted(address(token3)), true);

        vm.prank(recruiter1);
        token.approve(address(listing), 1 ether);
        vm.prank(recruiter2);
        token2.approve(address(listing), 2 ether);
        vm.prank(creator2);
        token3.approve(address(listing), 3 ether);
        vm.prank(recruiter1);
        listing.payForListing(address(token), 1 ether);
        vm.prank(recruiter2);
        listing.payForListing(address(token2), 1 ether);
        vm.prank(creator2);
        listing.payForListing(address(token3), 1 ether);

        assertEq(token.balanceOf(address(listing)), 1 ether);
        assertEq(token2.balanceOf(address(listing)), 1 ether);
        assertEq(token3.balanceOf(address(listing)), 1 ether);

        vm.prank(deployer);
        listing.withdrawToken();
        assertEq(token.balanceOf(address(listing)), 0 ether);
        assertEq(token2.balanceOf(address(listing)), 0 ether);
        assertEq(token3.balanceOf(address(listing)), 0 ether);
    }
}
