// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Payments/HonestPayLock.sol";
import "../src//HonestWorkNFT2.sol";
import "../src//Registry/HWRegistry.sol";



contract HonestPayLockTest is Test {

    enum Status {
        OfferInitiated,
        JobCompleted,
        JobCancelled
    }

    Status public status;

    HonestPayLock public hplock;
    HonestWorkNFT2 public hw721;
    HWRegistry public registry;
    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    function setUp() public {
        registry = new HWRegistry();
        hw721 = new HonestWorkNFT2();
        hplock = new HonestPayLock(address(registry), address(hw721), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
        recruiter1 = vm.addr(1);
        recruiter2 = vm.addr(2);
        creator1 = vm.addr(3);
        creator2 = vm.addr(4);
        vm.deal(recruiter1, 100 ether);
        vm.deal(recruiter2, 100 ether);
        vm.deal(creator1, 100 ether);
        vm.deal(creator2, 100 ether);
        vm.prank(recruiter1);
        hw721.publicMint{value: 10 ether }(address(recruiter1));
        hw721.publicMint{value: 10 ether }(address(recruiter2));
        hw721.publicMint{value: 10 ether }(address(creator1));
        hw721.publicMint{value: 10 ether }(address(creator2));

        hw721.setHonestPayLock((hplock));


        bool x = registry.addWhitelisted(address(0), 1000 ether);
        
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
        uint256 x = hplock.createDeal{value: 10 ether}(address(recruiter1), address(recruiter2), address(0), 10 ether, 1);
        assert(x == 1);

    }

    function testUnlockPayment() public {
        vm.prank(recruiter1);
        hplock.createDeal{value: 10 ether}(address(recruiter1), address(creator1), address(0), 10 ether, 1);
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
        hplock.claimPayment(1, 1 ether, 8, nftId );
        uint256 balanceAfter = creator1.balance;
        assert(balanceAfter> balanceBefore);

    }

    function testCompleteDeal() public {
        vm.prank(recruiter1);
        uint256 dealId = hplock.createDeal{value: 10 ether}(address(recruiter1), address(creator1), address(0), 10 ether, 1);
        vm.prank(recruiter1);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        hplock.unlockPayment(1,10 ether, 7, nftId);
        assertEq(hplock.getAvailablePayment(dealId), 10 ether);
        assertEq(hplock.getAvgCreatorRating(dealId), 700);

        vm.prank(creator1);
        nftId = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        uint256 balanceBefore = creator1.balance;
        vm.prank(creator1);
        hplock.claimPayment(dealId, 10 ether, 10, nftId );
        uint256 balanceAfter = creator1.balance;
        assert(balanceAfter> balanceBefore);
        uint256 paidAmount = hplock.getPaidAmount(dealId);
        //console.log(paidAmount);
        assertEq(hplock.getDealStatus(dealId), 1);

    }

    function testWithdrawPayment() public {
        vm.prank(recruiter1);
        hplock.createDeal{value: 10 ether}(address(recruiter1), address(creator1), address(0), 10 ether, 1);
        vm.prank(recruiter1);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        vm.prank(recruiter1);
        uint256 balanceBefore = recruiter1.balance;
        hplock.withdrawPayment(1);
        uint256 balanceAfter = recruiter1.balance;
        assertEq(balanceAfter - balanceBefore, 10 ether);



    }

}
