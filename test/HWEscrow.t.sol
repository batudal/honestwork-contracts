// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/HWEscrow.sol";
import "../src/HonestWorkNFT.sol";
import "../src/HWRegistry.sol";
import "../src/utils/MockToken.sol";
import "../src/utils/SigUtils.sol";

contract HWEscrowTest is Test {
    enum Status {
        OfferInitiated,
        JobCompleted,
        JobCancelled
    }

    Status public status;

    SigUtils public sigUtils;
    MockToken public token;
    MockToken public token2;
    MockToken public token3;
    HWEscrow public hplock;
    HonestWorkNFT public hw721;
    HWRegistry public registry;
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    uint256 internal creator1PrivateKey;
    uint256 internal recruiter1PrivateKey;
    uint256 internal creator2PrivateKey;
    uint256 internal recruiter2PrivateKey;

    function setUp() public {
        //pool 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16
        //busd 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
        //router 0x10ED43C718714eb63d5aA57B78B54704E256024E

        sigUtils = new SigUtils();
        creator1PrivateKey = 0xC1;
        recruiter1PrivateKey = 0xA1;
        creator2PrivateKey = 0xC2;
        recruiter2PrivateKey = 0xA2;

        recruiter1 = vm.addr(recruiter1PrivateKey);
        recruiter2 = vm.addr(recruiter2PrivateKey);
        creator1 = vm.addr(creator1PrivateKey);
        creator2 = vm.addr(creator2PrivateKey);

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
        token.transfer(address(recruiter2), 500 ether);
        token.transfer(address(creator2), 500 ether);
        vm.prank(deployer);
        token2.transfer(address(recruiter1), 500 ether);
        token2.transfer(address(creator1), 500 ether);
        token2.transfer(address(recruiter2), 500 ether);
        token2.transfer(address(creator2), 500 ether);
        vm.prank(deployer);
        token3.transfer(address(recruiter1), 500 ether);
        token3.transfer(address(creator1), 500 ether);
        token3.transfer(address(recruiter2), 500 ether);
        token3.transfer(address(creator2), 500 ether);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token);
        tokens[1] = address(token2);
        tokens[2] = address(0);

        registry = new HWRegistry();
        hw721 = new HonestWorkNFT("matrix", tokens);
        hplock = new HWEscrow(
            address(registry),
            0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16,
            0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56,
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );

        registry.setHWEscrow(address(hplock));

        vm.prank(recruiter1);

        token.approve(address(hplock), 10000 ether);
        vm.prank(recruiter1);
        token.approve(address(hw721), 10000 ether);

        vm.prank(recruiter2);
        token.approve(address(hplock), 10000 ether);
        vm.prank(recruiter2);
        token.approve(address(hw721), 10000 ether);

        vm.prank(creator1);
        token.approve(address(hplock), 10000 ether);
        vm.prank(creator1);
        token.approve(address(hw721), 10000 ether);

        vm.prank(creator2);
        token.approve(address(hplock), 10000 ether);
        vm.prank(creator2);
        token.approve(address(hw721), 10000 ether);

        hplock.allowNativePayment(true);

        vm.prank(deployer);
        registry.addWhitelisted(address(0), 1000 ether);
        vm.prank(deployer);
        registry.addWhitelisted(address(token), 1000 ether);
        vm.prank(deployer);
        registry.addWhitelisted(address(token2), 1000 ether);

        vm.prank(recruiter1);
        hw721.publicMint(address(token));
        vm.prank(recruiter2);
        hw721.publicMint(address(token));
        vm.prank(creator1);
        hw721.publicMint(address(token));
        vm.prank(creator2);
        hw721.publicMint(address(token));

        //console.log(x);
    }

    function testSetUp() public {
        assertEq(hw721.balanceOf(recruiter1), 1);
        assertEq(hw721.balanceOf(recruiter2), 1);
        assertEq(hw721.balanceOf(creator1), 1);
        assertEq(hw721.balanceOf(creator2), 1);

        assertTrue(registry.isWhitelisted(address(0)));
    }

    function testCreateDeal() public {
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );

        vm.prank(recruiter1);
        uint256 x = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        assert(x == 1);
    }

    // function testWrongSignature() public {
    //     bytes32 message = sigUtils.getMessageHash(address(recruiter1), address(creator1), address(0), 10 ether, 1 );
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(creator1PrivateKey, message);
    //     bytes memory wrongMessage = sigUtils.getMessageHash(address(recruiter1), address(creator1), address(0), 10 ether, 2);

    //     vm.prank(recruiter1);
    //     vm.expectRevert();
    //     hplock.createDealSignature{value: 10 ether}(
    //         address(recruiter1),
    //         address(creator1),
    //         address(0),
    //         10 ether,
    //         block.timestamp,
    //         wrongMessage
    //     );
    //}

    function testUnlockPayment() public {
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        vm.prank(recruiter1);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        hplock.unlockPayment(1, 2 ether, 7, nftId);
        assertEq(hplock.getClaimableAmount(1), 2 ether);
        assertEq(hplock.getAvgCreatorRating(1), 700);

        vm.prank(creator1);
        nftId = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        uint256 balanceBefore = creator1.balance;
        vm.prank(creator1);
        hplock.claimPayment(1, 1 ether, 8, nftId);
        uint256 balanceAfter = creator1.balance;
        assert(balanceAfter > balanceBefore);
    }

    function testCompleteDeal() public {
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        vm.prank(recruiter1);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        hplock.unlockPayment(1, 10 ether, 7, nftId);
        assertEq(hplock.getClaimableAmount(dealId), 10 ether);
        assertEq(hplock.getAvgCreatorRating(dealId), 700);

        vm.prank(creator1);
        nftId = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        uint256 balanceBefore = creator1.balance;
        vm.prank(creator1);
        hplock.claimPayment(dealId, 10 ether, 10, nftId);
        uint256 balanceAfter = creator1.balance;
        assert(balanceAfter > balanceBefore);
        //console.log(claimedAmount);
        assertEq(hplock.getDealStatus(dealId), 1);
    }

    function testWithdrawPayment() public {
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        //uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        uint256 balanceBefore = recruiter1.balance;
        hplock.withdrawPayment(1);
        uint256 balanceAfter = recruiter1.balance;
        assertEq(balanceAfter - balanceBefore, 10 ether);
        assertEq(hplock.getDealStatus(1), 2);
    }

    function testAdditionalPayment() public {
        vm.roll(100);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        vm.warp(300);
        vm.prank(recruiter1);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        hplock.additionalPayment{value: 5 ether}(dealId, 5 ether, nftId, 8);
        vm.warp(500);
        assertEq(hplock.getClaimableAmount(dealId), 5 ether);
        assertEq(hplock.getAvgCreatorRating(dealId), 800);
        assertEq(
            registry.getNFTGrossRevenue(nftId),
            hplock.getEthPrice(5 ether)
        );

        vm.prank(creator1);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 3 ether, 5, nftId2);
        assertEq(hplock.getClaimableAmount(dealId), 2 ether);
        assertEq(hplock.getAvgRecruiterRating(dealId), 500);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 2 ether, 5, nftId2);
        assertEq(hplock.getClaimableAmount(dealId), 0 ether);
        assertEq(hplock.getclaimedAmount(dealId), 5 ether);
        assertEq(hplock.getTotalPayment(dealId), 15 ether);
        assertEq(hplock.getAdditionalPaymentLimit(dealId), 1);
    }

    function testAccess() public {
        vm.roll(100);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter2);
        vm.expectRevert();
        hplock.additionalPayment(dealId, 5 ether, nftId, 6);
        vm.prank(creator2);
        vm.expectRevert();
        hplock.claimPayment(dealId, 2 ether, 6, nftId2);
        vm.prank(creator1);
        vm.expectRevert();
        hplock.claimPayment(dealId, 2 ether, 6, nftId2);
        vm.prank(creator1);
        vm.expectRevert();
        hplock.withdrawPayment(dealId);
        vm.prank(creator1);
        vm.expectRevert();
        hplock.unlockPayment(dealId, 6 ether, 9, nftId);
    }

    function testGrossRevenue() public {
        vm.roll(100);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 3 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 4 ether, 7, nftId);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 7 ether, 10, nftId2);

        assertApproxEqAbs(
            registry.getNFTGrossRevenue(nftId),
            hplock.getEthPrice(7 ether),
            1000000
        );
        assertApproxEqAbs(
            registry.getNFTGrossRevenue(nftId2),
            hplock.getEthPrice(7 ether),
            100000
        );

        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 3 ether, 7, nftId);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 3 ether, 10, nftId2);

        assertApproxEqAbs(
            registry.getNFTGrossRevenue(nftId),
            hplock.getEthPrice(10 ether),
            1000000
        );
        assertApproxEqAbs(
            registry.getNFTGrossRevenue(nftId2),
            hplock.getEthPrice(10 ether),
            100000
        );
        assertEq(hplock.getDealStatus(dealId), 1);

        message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            20 ether,
            0
        );
        (v, r, s) = vm.sign(creator1PrivateKey, message);

        // dealId = hplock.createDeal{value: 20 ether}(
        //     address(recruiter1),
        //     address(creator1),
        //     address(0),
        //     20 ether,
        //     1,v,r,s,
        //     message
        // );
        // vm.prank(recruiter1);
        // hplock.unlockPayment(dealId, 9 ether, 7, nftId);
        // vm.prank(recruiter1);
        // hplock.unlockPayment(dealId, 2 ether, 7, nftId);
        // vm.prank(creator1);
        // hplock.claimPayment(dealId, 5 ether, 10, nftId2);

        // assertApproxEqAbs(hw721.getGrossRevenue(nftId), hplock.getEthPrice(21 ether), 1000000);
        // assertApproxEqAbs(hw721.getGrossRevenue(nftId2), hplock.getEthPrice(15 ether),100000);
    }

    function testSuccessFee() public {
        vm.roll(100);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        // uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        // uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        // vm.warp(300);
        // vm.prank(recruiter2);
        // bytes32 message2 = sigUtils.getMessageHash(address(recruiter2), address(creator2), address(0), 20 ether, 2);
        // (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(creator2PrivateKey, message2);
        // vm.prank(recruiter2);
        // uint256 dealId2 = hplock.createDeal{value: 20 ether}(
        //     address(recruiter2),
        //     address(creator2),
        //     address(0),
        //     20 ether,
        //     1,v,r,s
        // );

        // vm.prank(recruiter1);
        // hplock.unlockPayment(dealId, 5 ether, 7, nftId);
        // vm.prank(recruiter1);
        // hplock.unlockPayment(dealId, 5 ether, 7, nftId);
        // vm.prank(creator1);
        // hplock.claimPayment(dealId, 10 ether, 10, nftId2);

        // assertEq(hplock.getDealSuccessFee(dealId), 500000000000000000);

        // vm.warp(800);
        // uint256 nftId3 = hw721.tokenOfOwnerByIndex(address(recruiter2), 0);
        // uint256 nftId4 = hw721.tokenOfOwnerByIndex(address(creator2), 0);

        // vm.prank(recruiter2);
        // hplock.unlockPayment(dealId2, 10 ether, 7, nftId3);
        // vm.prank(recruiter2);
        // hplock.unlockPayment(dealId2, 5 ether, 7, nftId3);
        // vm.prank(creator2);
        // hplock.claimPayment(dealId2, 15 ether, 10, nftId4);

        // assertEq(hplock.getDealSuccessFee(dealId2), 750000000000000000);
    }

    function testOverUnlock() public {
        vm.roll(100);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 3 ether, 7, nftId);
        vm.prank(recruiter1);
        vm.expectRevert();
        hplock.unlockPayment(dealId, 14 ether, 7, nftId);
    }

    function testOverClaim() public {
        vm.roll(100);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 3 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 2 ether, 7, nftId);

        vm.prank(creator1);
        vm.expectRevert();
        hplock.claimPayment(dealId, 8 ether, 10, nftId2);
    }

    function testOverClaim2() public {
        vm.roll(100);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 3 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 2 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.additionalPayment{value: 2 ether}(dealId, 2 ether, nftId, 8);

        vm.prank(creator1);
        vm.expectRevert();
        hplock.claimPayment(dealId, 8 ether, 10, nftId2);
    }

    function testClaimAfterCompletion() public {
        vm.roll(100);
        vm.prank(recruiter1);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.additionalPayment{value: 2 ether}(dealId, 2 ether, nftId, 8);

        vm.prank(creator1);
        hplock.claimPayment(dealId, 12 ether, 10, nftId2);
        assertEq(hplock.getDealStatus(dealId), 1);
        vm.prank(creator1);
        vm.expectRevert();
        hplock.claimPayment(dealId, 1 ether, 10, nftId2);
        vm.prank(recruiter1);
        vm.expectRevert();
        hplock.additionalPayment{value: 2 ether}(dealId, 2 ether, nftId, 8);
    }

    function testNativePrice() public {
        uint256 price = hplock.getEthPrice(1 ether);
        //console.log("price:" , price);
    }

    // function testgetDealsOf(uint256 _totalPayment, uint256 _nonce) public {
    //     bytes32 message = sigUtils.getMessageHash(address(recruiter1), address(creator1), address(0), 10 ether, _nonce);
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(creator1PrivateKey, message);
    //     for(uint256 i=0; i<100; i++){
    //         vm.assume(_totalPayment < 9500);
    //         vm.prank(recruiter1);
    //         uint256 dealId = hplock.createDeal{value: _totalPayment}(
    //             address(recruiter1),
    //             address(creator1),
    //             address(0),
    //             _totalPayment,
    //             _nonce,v,r,s,
    //             message
    //         );
    //     }
    //     assert(hplock.getDealsOf(address(recruiter1)).length == 100);

    // }

    function testDealWithToken() public {
        console.log(token.balanceOf(address(recruiter1)));
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        vm.prank(recruiter1);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);

        vm.prank(creator1);
        hplock.claimPayment(dealId, 5 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            405 ether,
            300000000000000000
        );
    }

    function testAdditionalPaymentWithToken() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);

        vm.prank(creator1);
        hplock.claimPayment(dealId, 5 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            405 ether,
            300000000000000000
        );
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        vm.prank(recruiter1);
        hplock.additionalPayment(dealId, 5 ether, nftId, 8);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 5 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            410 ether,
            500000000000000000
        );
    }

    function testCompleteDealWithToken() public {
        vm.roll(100);
        vm.prank(recruiter1);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        vm.prank(recruiter1);
        hplock.additionalPayment(dealId, 2 ether, nftId, 8);
        console.log(token.balanceOf(creator1));
        vm.prank(creator1);
        hplock.claimPayment(dealId, 12 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            412 ether,
            1000000000000000000
        );
        assertEq(hplock.getDealStatus(dealId), 1);
    }

    function testWithdrawPaymentWithToken() public {
        vm.roll(100);
        vm.prank(recruiter1);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        vm.prank(recruiter1);
        uint256 balanceBefore = token.balanceOf(address(recruiter1));
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.withdrawPayment(dealId);
        uint256 balanceAfter = token.balanceOf(address(recruiter1));
        assertEq(balanceAfter, balanceBefore);
    }

    function testWithdrawPaymentWithToken2() public {
        vm.roll(100);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        vm.prank(recruiter1);
        uint256 balanceBefore = token.balanceOf(address(recruiter1));
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 3 ether, 5, nftId);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 1 ether, 10, nftId2);

        vm.prank(recruiter1);
        hplock.withdrawPayment(dealId);
        uint256 balanceAfter = token.balanceOf(address(recruiter1));
        assertEq(balanceAfter + 1 ether, balanceBefore);
    }

    function testGrossRevenueWithToken() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);

        vm.prank(creator1);
        hplock.claimPayment(dealId, 5 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            405 ether,
            300000000000000000
        );
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        vm.prank(recruiter1);
        hplock.additionalPayment(dealId, 5 ether, nftId, 8);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 5 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            410 ether,
            500000000000000000
        );
        vm.prank(recruiter1);
        assertApproxEqAbs(
            registry.getNFTGrossRevenue(nftId2),
            10 ether,
            (10 ether * 6) / 100
        );
    }
}
