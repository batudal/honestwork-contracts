// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/HWEscrow.sol";
import "../src/HonestWorkNFT.sol";
import "../src/HWRegistry.sol";
import "../src/HWListing.sol";
import "../src/utils/MockToken.sol";

contract HWRegistryTest is Test {
    HWRegistry public registry;
    MockToken public token;
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    function setUp() public {
        registry = new HWRegistry();
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

        //console.log(x);
    }

    function testAddWhitelist(address _address) public {
        vm.prank(deployer);
        registry.addToWhitelist(_address, 1000 ether);
        assertEq(registry.isWhitelisted(_address), true);
    }

    function testAddWhitelistWithToken() public {
        vm.prank(deployer);
        registry.addToWhitelist(address(token), 1000 ether);
        assertEq(registry.isWhitelisted(address(token)), true);
        assertEq(registry.isWhitelisted(address(token)), true);
        assertEq(registry.isAllowedAmount(address(token), 1500 ether), false);
        assertEq(registry.isAllowedAmount(address(token), 500 ether), true);
    }

    function testUpdateWhitelisted() public {
        vm.prank(deployer);
        registry.addToWhitelist(address(token), 1000 ether);
        assertEq(registry.isWhitelisted(address(token)), true);
        assertEq(registry.isAllowedAmount(address(token), 1500 ether), false);
        assertEq(registry.isAllowedAmount(address(token), 500 ether), true);
        registry.updateWhitelist(address(token), 1500 ether);
        assertEq(registry.isAllowedAmount(address(token), 1500 ether), true);
        assertEq(registry.isAllowedAmount(address(token), 500 ether), true);
        assertEq(registry.isAllowedAmount(address(token), 2000 ether), false);
    }

    function testAddWhitelist(address _adress, uint256 _amount) public {
        vm.assume(_amount < 1000000000 ether);
        vm.prank(deployer);
        registry.addToWhitelist(_adress, _amount);
        assertEq(registry.isWhitelisted(_adress), true);
        assertEq(registry.isAllowedAmount(_adress, _amount), true);
        assertEq(registry.isAllowedAmount(_adress, _amount + 1), false);
    }

    function testRemoveWhitelisted() public {
        vm.prank(deployer);
        registry.addToWhitelist(address(token), 1000 ether);
        assertEq(registry.isWhitelisted(address(token)), true);
        vm.prank(deployer);
        registry.removeFromWhitelist(address(token));
        assertEq(registry.isWhitelisted(address(token)), false);
    }
}
