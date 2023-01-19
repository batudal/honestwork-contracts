// // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/Payments/HonestPayLock.sol";
import "../src//HonestWorkNFT.sol";
import "../src//Registry/HWRegistry.sol";
import "../src//Jobs/JobListing.sol";
import "../src//mock/MockToken.sol";

contract HonestPayLockTest is Test {


    HWRegistry public registry;
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    function setUp() public {
        registry = new HWRegistry();
        jobListing = new JobListing(address(registry));
        token = new MockToken("MCK", "MOCK");


        recruiter1 = vm.addr(1);
        recruiter2 = vm.addr(2);
        creator1 = vm.addr(3);
        creator2 = vm.addr(4);
        vm.deal(recruiter1, 100 ether);
        vm.deal(recruiter2, 100 ether);
        vm.deal(creator1, 100 ether);
        vm.deal(creator2, 100 ether);
        vm.prank(recruiter1);


        registry.addWhitelisted(address(0), 1000 ether);

        //console.log(x);
    }

    function testSetup() public {
        assertEq(token.balanceOf(address(deployer)),10000000e18);


    }

}