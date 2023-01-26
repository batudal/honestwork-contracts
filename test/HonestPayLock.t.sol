// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Payments/HonestPayLock.sol";
import "../src//HonestWorkNFT.sol";
import "../src//Registry/HWRegistry.sol";
import "../src//mock/MockToken.sol";

contract HonestPayLockTest is Test {
    enum Status {
        OfferInitiated,
        JobCompleted,
        JobCancelled
    }

    Status public status;


    MockToken public token;
    MockToken public token2;
    HonestPayLock public hplock;
    HonestWorkNFT public hw721;
    HWRegistry public registry;
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    function setUp() public {
        registry = new HWRegistry();
        hw721 = new HonestWorkNFT();
        hplock = new HonestPayLock(
            address(registry),
            address(hw721)
        );

        token = new MockToken("MCK", "MOCK");
        token2 = new MockToken("MCK", "MOCK");

        recruiter1 = vm.addr(1);
        recruiter2 = vm.addr(2);
        creator1 = vm.addr(3);
        creator2 = vm.addr(4);
        vm.deal(recruiter1, 100 ether);
        vm.deal(recruiter2, 100 ether);
        vm.deal(creator1, 100 ether);
        vm.deal(creator2, 100 ether);
        vm.prank(recruiter1);
        hw721.publicMint{value: 10 ether}(address(recruiter1));
        hw721.publicMint{value: 10 ether}(address(recruiter2));
        hw721.publicMint{value: 10 ether}(address(creator1));
        hw721.publicMint{value: 10 ether}(address(creator2));

        token.transfer(address(recruiter1), 20 ether);
        token2.transfer(address(recruiter2), 30 ether);


        hw721.setHonestPayLock((hplock));
        registry.addWhitelisted(address(0), 1000 ether);
        registry.addWhitelisted(address(token), 1000 ether);
        registry.addWhitelisted(address(token2), 1000 ether);

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
        vm.prank(recruiter1);
        uint256 x = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(recruiter2),
            address(0),
            10 ether,
            1
        );
        assert(x == 1);
    }

    function testUnlockPayment() public {
        vm.prank(recruiter1);
        hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
        );
        vm.prank(recruiter1);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        hplock.unlockPayment(1, 2 ether, 7, nftId);
        assertEq(hplock.getAvailablePayment(1), 2 ether);
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
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
        );
        vm.prank(recruiter1);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        hplock.unlockPayment(1, 10 ether, 7, nftId);
        assertEq(hplock.getAvailablePayment(dealId), 10 ether);
        assertEq(hplock.getAvgCreatorRating(dealId), 700);

        vm.prank(creator1);
        nftId = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        uint256 balanceBefore = creator1.balance;
        vm.prank(creator1);
        hplock.claimPayment(dealId, 10 ether, 10, nftId);
        uint256 balanceAfter = creator1.balance;
        assert(balanceAfter > balanceBefore);
        //console.log(paidAmount);
        assertEq(hplock.getDealStatus(dealId), 1);
    }

    function testWithdrawPayment() public {
        vm.prank(recruiter1);
        hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
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
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
        );
        vm.warp(300);
        vm.prank(recruiter1);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        hplock.additionalPayment{value: 5 ether}(dealId, 5 ether, nftId, 8);
        vm.warp(500);
        assertEq(hplock.getAvailablePayment(dealId), 5 ether);
        assertEq(hplock.getAvgCreatorRating(dealId), 800);
        assertEq(hw721.getGrossRevenue(nftId), hplock.getBnbPrice(5 ether));

        vm.prank(creator1);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 3 ether, 5, nftId2);
        assertEq(hplock.getAvailablePayment(dealId), 2 ether);
        assertEq(hplock.getAvgRecruiterRating(dealId), 500);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 2 ether, 5, nftId2);
        assertEq(hplock.getAvailablePayment(dealId), 0 ether);
        assertEq(hplock.getPaidAmount(dealId), 5 ether);
        assertEq(hplock.getTotalPayment(dealId), 15 ether);
        assertEq(hplock.getAdditionalPaymentLimit(dealId), 1);
    }

    function testAccess() public {
        vm.roll(100);
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
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
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
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

        assertApproxEqAbs(hw721.getGrossRevenue(nftId), hplock.getBnbPrice(7 ether), 1000000);
        assertApproxEqAbs(hw721.getGrossRevenue(nftId2), hplock.getBnbPrice(7 ether),100000);

        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 3 ether, 7, nftId);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 3 ether, 10, nftId2);

        assertApproxEqAbs(hw721.getGrossRevenue(nftId), hplock.getBnbPrice(10 ether), 1000000);
        assertApproxEqAbs(hw721.getGrossRevenue(nftId2), hplock.getBnbPrice(10 ether),100000);
        assertEq(hplock.getDealStatus(dealId), 1);

        dealId = hplock.createDeal{value: 20 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            20 ether,
            1
        );
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 9 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 2 ether, 7, nftId);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 5 ether, 10, nftId2);

        assertApproxEqAbs(hw721.getGrossRevenue(nftId), hplock.getBnbPrice(21 ether), 1000000);
        assertApproxEqAbs(hw721.getGrossRevenue(nftId2), hplock.getBnbPrice(15 ether),100000);
    }

    function testSuccessFee() public {
        vm.roll(100);
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter2);
        uint256 dealId2 = hplock.createDeal{value: 20 ether}(
            address(recruiter2),
            address(creator2),
            address(0),
            20 ether,
            2
        );

        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);
        vm.prank(creator1);
        hplock.claimPayment(dealId, 10 ether, 10, nftId2);

        assertEq(hplock.getDealSuccessFee(dealId), 500000000000000000);

        vm.warp(800);
        uint256 nftId3 = hw721.tokenOfOwnerByIndex(address(recruiter2), 0);
        uint256 nftId4 = hw721.tokenOfOwnerByIndex(address(creator2), 0);

        vm.prank(recruiter2);
        hplock.unlockPayment(dealId2, 10 ether, 7, nftId3);
        vm.prank(recruiter2);
        hplock.unlockPayment(dealId2, 5 ether, 7, nftId3);
        vm.prank(creator2);
        hplock.claimPayment(dealId2, 15 ether, 10, nftId4);

        assertEq(hplock.getDealSuccessFee(dealId2), 750000000000000000);
    }

    function testOverUnlock() public {
        vm.roll(100);
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
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
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
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
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
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
        uint256 dealId = hplock.createDeal{value: 10 ether}(
            address(recruiter1),
            address(creator1),
            address(0),
            10 ether,
            1
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
        uint256 price = hplock.getBnbPrice(1 ether);
        //console.log("price:" , price);
    }

    function testDealWithToken() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(hplock), 10 ether);
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            1
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        hplock.unlockPayment(dealId, 5 ether, 7, nftId);

        vm.prank(creator1);
        hplock.claimPayment(dealId, 5 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(token.balanceOf(address(creator1)), 5 ether,300000000000000000);
    }
}
