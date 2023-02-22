// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Payments/HWEscrow.sol";
import "../src//HonestWorkNFT.sol";
import "../src//Registry/HWRegistry.sol";
import "../src//Jobs/JobListing.sol";
import "../src//mock/MockToken.sol";

contract JobListingTest is Test {
    struct Payment {
        address token; // 0x0 for ETH
        uint256 amount;
        uint256 listingDate;
    }

    uint256 bscFork;

    HWRegistry public registry;
    JobListing public jobListing;
    MockToken public token;
    MockToken public token2;
    MockToken public token3;
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    function setUp() public {
        bscFork = vm.createFork("https://bsc-dataseed.binance.org/");
        vm.selectFork(bscFork);
        registry = new HWRegistry();
        jobListing = new JobListing(address(registry));
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

        //console.log(x);
    }

    function testSetup() public {
        assertEq(token.balanceOf(address(deployer)), 49999 ether);
        assertEq(registry.isWhitelisted(address(token)), false);
        assertEq(token.balanceOf(address(recruiter1)), 1e18);
    }

    function testAddWhitelist() public {
        vm.prank(deployer);
        registry.addWhitelisted(address(token), 1000 ether);
        assertEq(registry.isWhitelisted(address(token)), true);
        vm.prank(recruiter1);
        token.approve(address(jobListing), 2 ether);
        vm.prank(recruiter1);
        jobListing.payForListing(address(token), 1 ether);

        assertEq(token.balanceOf(address(recruiter1)), 0 ether);
        assertEq(token.balanceOf(address(jobListing)), 1 ether);
        assertEq(token.balanceOf(address(deployer)), 49999 ether);
        assertEq(token.balanceOf(address(registry)), 0 ether);
        assertEq(
            jobListing.getLatestPayment(address(recruiter1)).amount,
            1 ether
        );
        assertEq(
            jobListing.getLatestPayment(address(recruiter1)).token,
            address(token)
        );
        assertEq(
            jobListing.getLatestPayment(address(recruiter1)).listingDate,
            block.timestamp
        );
    }

    function testPayForListingEth() public {
        vm.selectFork(bscFork);
        assertEq(vm.activeFork(), bscFork);
        vm.prank(deployer);
        registry.addWhitelisted(address(0), 1000 ether);
        assertEq(registry.isWhitelisted(address(0)), true);
        vm.prank(recruiter1);
        jobListing.payForListingEth{value: 1 ether}(200 ether, 100);
        assert(jobListing.getTokenBalance() > 200 ether);
        //console.log(jobListing.getTokenBalance());
        vm.prank(deployer);
        jobListing.withdrawAllEarnings(
            0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
        );
        assertEq(token.balanceOf(address(jobListing)), 0 ether);
    }

    function testWithdrawAll() public {
        vm.prank(deployer);
        registry.addWhitelisted(address(token), 1000 ether);
        registry.addWhitelisted(address(token2), 1000 ether);
        registry.addWhitelisted(address(token3), 1000 ether);
        registry.addWhitelisted(address(0), 1000 ether);
        assertEq(registry.isWhitelisted(address(token)), true);
        assertEq(registry.isWhitelisted(address(token2)), true);
        assertEq(registry.isWhitelisted(address(token3)), true);

        vm.prank(recruiter1);
        token.approve(address(jobListing), 1 ether);

        vm.prank(recruiter2);
        token2.approve(address(jobListing), 2 ether);

        vm.prank(creator2);
        token3.approve(address(jobListing), 3 ether);

        vm.prank(recruiter1);
        jobListing.payForListing(address(token), 1 ether);

        vm.prank(recruiter2);
        jobListing.payForListing(address(token2), 1 ether);

        vm.prank(creator2);
        jobListing.payForListing(address(token3), 1 ether);

        assertEq(token.balanceOf(address(jobListing)), 1 ether);
        assertEq(token2.balanceOf(address(jobListing)), 1 ether);
        assertEq(token3.balanceOf(address(jobListing)), 1 ether);

        vm.prank(deployer);
        jobListing.withdrawAllTokens();
        assertEq(token.balanceOf(address(jobListing)), 0 ether);
        assertEq(token2.balanceOf(address(jobListing)), 0 ether);
        assertEq(token3.balanceOf(address(jobListing)), 0 ether);
    }

    function testgetEthPrice() public {
        vm.prank(deployer);
        assert(jobListing.getEthPrice(1 ether) > 250 ether);
    }
}
