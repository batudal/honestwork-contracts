pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Payments/HonestPayLock.sol";
import "../src//HonestWorkNFT.sol";
import "../src//Registry/HWRegistry.sol";
import "../src//Jobs/JobListing.sol";
import "../src//mock/MockToken.sol";
import "../src/HonestWorkNFT.sol";

contract HonestWorkNFTTest is Test {
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;
    HonestWorkNFT public honestWorkNFT;

    function setUp() public {
        honestWorkNFT = new HonestWorkNFT(address(0));

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

    function testWhitelistMint() public {
        vm.prank(deployer);
        honestWorkNFT.setWhitelistRoot(
            0xbaad0cf668c3a28309eef83f54b1cec6ec6fe30c3366834fe377692bddd00d2c
        );
        console.log(address(deployer));
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = 0xbcc5c7028396f7064f8e72141f9b6859a7531c1050c0a9653b5976d0f9a29425;
        proof[1] = 0x997428aaf974eaee0f8be9b9ff90dd63c706a283e1491edafa97a5f91c58a44b;
        proof[2] = 0xec6c60123b0ce977603d6b7a9828d99243686efec9f424b49bb48e2860b0ff13;

        vm.prank(deployer);
        honestWorkNFT.whitelistMint(
            address(deployer),proof
        );
        assertEq(honestWorkNFT.balanceOf(address(deployer)), 1);
    }
}

// address recipient,
// bytes32[] calldata _proof
