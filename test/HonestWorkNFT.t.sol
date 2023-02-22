// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Payments/HWEscrow.sol";
import "../src//HonestWorkNFT.sol";
import "../src//Registry/HWRegistry.sol";
import "../src//Jobs/HWListing.sol";
import "../src//mock/MockToken.sol";
import "../src/HonestWorkNFT.sol";

contract HonestWorkNFTTest is Test {
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    SigUtils public sigUtils;
    MockToken public token;
    MockToken public token2;
    MockToken public token3;
    HWEscrow public hplock;
    HonestWorkNFT public honestWorkNFT;
    HWRegistry public registry;

    function setUp() public {
        recruiter1 = vm.addr(1);
        recruiter2 = vm.addr(2);
        creator1 = vm.addr(3);
        creator2 = vm.addr(4);
        vm.deal(recruiter1, 500 ether);
        vm.deal(recruiter2, 500 ether);
        vm.deal(creator1, 100 ether);
        vm.deal(creator2, 100 ether);

        token = new MockToken("MCK", "MOCK");
        token2 = new MockToken("MCK", "MOCK");
        token3 = new MockToken("MCK", "MOCK");

        vm.prank(deployer);
        token.transfer(address(recruiter1), 500 ether);
        token.transfer(address(creator1), 500 ether);
        vm.prank(deployer);
        token2.transfer(address(recruiter1), 500 ether);
        token2.transfer(address(creator1), 500 ether);
        vm.prank(deployer);
        token3.transfer(address(recruiter1), 500 ether);
        token3.transfer(address(creator1), 500 ether);

        registry = new HWRegistry();
        address[] memory tokens = new address[](3);
        tokens[0] = address(token);
        tokens[1] = address(token2);
        tokens[2] = address(0);

        honestWorkNFT = new HonestWorkNFT("matrix", tokens);
        hplock = new HWEscrow(
            address(registry),
            address(honestWorkNFT),
            0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16,
            0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56,
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        sigUtils = new SigUtils();

        //console.log(x);
    }

    function testWhitelistMint() public {
        vm.prank(deployer);
        honestWorkNFT.setWhitelistRoot(
            0xbaad0cf668c3a28309eef83f54b1cec6ec6fe30c3366834fe377692bddd00d2c
        );
        //console.log(address(deployer));
        bytes32[] memory proof = new bytes32[](3);
        proof[
            0
        ] = 0xbcc5c7028396f7064f8e72141f9b6859a7531c1050c0a9653b5976d0f9a29425;
        proof[
            1
        ] = 0x997428aaf974eaee0f8be9b9ff90dd63c706a283e1491edafa97a5f91c58a44b;
        proof[
            2
        ] = 0xec6c60123b0ce977603d6b7a9828d99243686efec9f424b49bb48e2860b0ff13;

        vm.prank(deployer);
        honestWorkNFT.whitelistMint(proof);
        assertEq(honestWorkNFT.balanceOf(address(deployer)), 1);
    }

    function testPublicMint() public {
        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);

        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.expectRevert();
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);

        vm.prank(creator1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(creator1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(creator1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(creator1), 0), 2);
    }

    function testTierFeeChange(
        uint256 _tierOneFee,
        uint256 _tierTwoFee,
        uint256 _tierThreeFee
    ) public {
        honestWorkNFT.setTiers(_tierOneFee, _tierTwoFee, _tierThreeFee);
        assertEq(honestWorkNFT.tierOneFee(), _tierOneFee);
        assertEq(honestWorkNFT.tierTwoFee(), _tierTwoFee);
        assertEq(honestWorkNFT.tierThreeFee(), _tierThreeFee);
    }

    function testWhitelistToken(address _token) public {
        honestWorkNFT.whitelistToken(_token);
        assertEq(honestWorkNFT.getWhitelistToken(_token), true);
    }

    function testPause() public {
        honestWorkNFT.pause();
        assertEq(honestWorkNFT.isPaused(), true);

        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.expectRevert();
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
    }

    function testUpgradeToken2levels() public {
        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);

        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 200 ether);
        vm.prank(recruiter1);
        honestWorkNFT.upgradeToken(address(token), 2);
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);
        assertEq(honestWorkNFT.getTokenTier(1), 3);
        assertEq(token.balanceOf(address(honestWorkNFT)), 300 ether);
    }

    function testUpgradeToken1Level() public {
        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);

        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 151 ether);
        vm.prank(recruiter1);
        honestWorkNFT.upgradeToken(address(token), 1);
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);
        assertEq(honestWorkNFT.getTokenTier(1), 2);
        assertEq(token.balanceOf(address(honestWorkNFT)), 250 ether);
    }

    function testUpgradeTokenLevel2to3() public {
        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 200 ether);
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);

        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 200 ether);
        vm.prank(recruiter1);
        honestWorkNFT.upgradeToken(address(token), 1);
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);
        assertEq(honestWorkNFT.getTokenTier(1), 2);
        assertEq(token.balanceOf(address(honestWorkNFT)), 250 ether);

        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 200 ether);
        vm.prank(recruiter1);
        honestWorkNFT.upgradeToken(address(token), 1);

        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);
        assertEq(honestWorkNFT.getTokenTier(1), 3);
        assertEq(token.balanceOf(address(honestWorkNFT)), 300 ether);
    }

    function testMultipleMinting() public {
        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);

        vm.prank(recruiter1);
        token2.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        vm.expectRevert();
        honestWorkNFT.publicMint(address(token2));
    }

    function testMultipleWhitelistMinting() public {
        vm.prank(deployer);
        honestWorkNFT.setWhitelistRoot(
            0xbaad0cf668c3a28309eef83f54b1cec6ec6fe30c3366834fe377692bddd00d2c
        );
        //console.log(address(deployer));
        bytes32[] memory proof = new bytes32[](3);
        proof[
            0
        ] = 0xbcc5c7028396f7064f8e72141f9b6859a7531c1050c0a9653b5976d0f9a29425;
        proof[
            1
        ] = 0x997428aaf974eaee0f8be9b9ff90dd63c706a283e1491edafa97a5f91c58a44b;
        proof[
            2
        ] = 0xec6c60123b0ce977603d6b7a9828d99243686efec9f424b49bb48e2860b0ff13;

        vm.prank(deployer);
        honestWorkNFT.whitelistMint(proof);
        assertEq(honestWorkNFT.balanceOf(address(deployer)), 1);

        vm.expectRevert();
        vm.prank(deployer);
        honestWorkNFT.whitelistMint(proof);
    }

    function testUnpause() public {
        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);

        honestWorkNFT.pause();

        vm.prank(creator1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(creator1);
        vm.expectRevert();
        honestWorkNFT.publicMint(address(token));

        honestWorkNFT.unpause();

        vm.prank(creator1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(creator1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(creator1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(creator1), 0), 2);
    }

    function testWithdraw() public {
        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);

        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        honestWorkNFT.upgradeToken(address(token), 1);
        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);
        assertEq(honestWorkNFT.getTokenTier(1), 2);
        assertEq(token.balanceOf(address(honestWorkNFT)), 250 ether);

        vm.prank(deployer);
        honestWorkNFT.withdraw(address(token), 250 ether);
        assertEq(token.balanceOf(address(honestWorkNFT)), 0);
    }

    function testAdminMint() public {
        vm.prank(deployer);
        honestWorkNFT.adminMint(address(deployer), 1);
        assertEq(honestWorkNFT.balanceOf(address(deployer)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(deployer), 0), 1);

        vm.prank(deployer);
        honestWorkNFT.adminMint(address(deployer), 2);
        assertEq(honestWorkNFT.balanceOf(address(deployer)), 2);

        vm.prank(deployer);
        honestWorkNFT.adminMint(address(deployer), 3);
        assertEq(honestWorkNFT.balanceOf(address(deployer)), 3);

        assertEq(honestWorkNFT.getTokenTier(1), 1);
        assertEq(honestWorkNFT.getTokenTier(2), 2);
        assertEq(honestWorkNFT.getTokenTier(3), 3);
    }

    function testRemoveWhitelistToken() public {
        honestWorkNFT.removeWhitelistToken(address(token));
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        vm.expectRevert();
        honestWorkNFT.publicMint(address(token));

        vm.prank(deployer);
        honestWorkNFT.whitelistToken(address(token));
        vm.prank(recruiter1);
        token.approve(address(honestWorkNFT), 150 ether);
        vm.prank(recruiter1);
        honestWorkNFT.publicMint(address(token));

        assertEq(honestWorkNFT.balanceOf(address(recruiter1)), 1);
        assertEq(honestWorkNFT.tokenOfOwnerByIndex(address(recruiter1), 0), 1);
    }
}

// address recipient,
// bytes32[] calldata _proof
