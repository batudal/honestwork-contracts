// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/HWEscrow.sol";
import "../src/HonestWorkNFT.sol";
import "../src/HWRegistry.sol";
import "../src/utils/MockToken.sol";
import "../src/utils/SigUtils.sol";
import "../src/interfaces/IHWRegistry.sol";
import "forge-std/console.sol";

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
    HWEscrow public escrow;
    HonestWorkNFT public hw721;
    HWRegistry public registry;

    uint128 public testFee = 5;
    uint128 immutable PRECISION = 1e2;

    address public deployer = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address public recruiter1;
    address public recruiter2;
    address public creator1;
    address public creator2;

    address[] public tokens;

    uint256 internal creator1PrivateKey;
    uint256 internal recruiter1PrivateKey;
    uint256 internal creator2PrivateKey;
    uint256 internal recruiter2PrivateKey;

    struct Deal {
        address recruiter;
        address creator;
        address paymentToken;
        uint256 totalPayment;
        uint256 hwProfit;
        uint256 claimedAmount;
        uint256 claimableAmount;
        uint256 jobId;
        Status status;
        uint128[] recruiterRating;
        uint128[] creatorRating;
    }

    function setUp() public {
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

        tokens.push(address(token));
        tokens.push(address(token2));

        registry = new HWRegistry();
        hw721 = new HonestWorkNFT("matrix", tokens);
        escrow = new HWEscrow(address(registry), testFee);
        registry.setHWEscrow(address(escrow));

        vm.prank(recruiter1);
        token.approve(address(escrow), 10000 ether);
        vm.prank(recruiter1);
        token.approve(address(hw721), 10000 ether);
        vm.prank(recruiter2);
        token.approve(address(escrow), 10000 ether);
        vm.prank(recruiter2);
        token.approve(address(hw721), 10000 ether);
        vm.prank(creator1);
        token.approve(address(escrow), 10000 ether);
        vm.prank(creator1);
        token.approve(address(hw721), 10000 ether);
        vm.prank(creator2);
        token.approve(address(escrow), 10000 ether);
        vm.prank(creator2);
        token.approve(address(hw721), 10000 ether);

        vm.prank(deployer);
        registry.addToWhitelist(address(token), 1000 ether);
        vm.prank(deployer);
        registry.addToWhitelist(address(token2), 1000 ether);

        vm.prank(recruiter1);
        hw721.publicMint(address(token));
        vm.prank(recruiter2);
        hw721.publicMint(address(token));
        vm.prank(creator1);
        hw721.publicMint(address(token));
        vm.prank(creator2);
        hw721.publicMint(address(token));
    }

    function testSetUp() public {
        assertEq(hw721.balanceOf(recruiter1), 1);
        assertEq(hw721.balanceOf(recruiter2), 1);
        assertEq(hw721.balanceOf(creator1), 1);
        assertEq(hw721.balanceOf(creator2), 1);
        assertTrue(registry.isWhitelisted(address(tokens[0])));
        assertTrue(registry.isWhitelisted(address(tokens[1])));
        assertEq(escrow.getAggregatedRating(recruiter1), 0);
    }

    function testDeal() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        vm.prank(recruiter1);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 5 ether, 7, nftId);

        uint256 beforePayment = token.balanceOf(address(creator1));
        vm.prank(creator1);
        escrow.claimPayment(dealId, 5 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            beforePayment + 5 ether,
            300000000000000000
        );
    }

    function testCompleteDeal() public {
        vm.roll(100);
        vm.prank(recruiter1);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        uint256 beforePayment = token.balanceOf(address(creator1));
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 5 ether, 7, nftId);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 5 ether, 7, nftId);
        vm.prank(creator1);
        escrow.claimPayment(dealId, 10 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            beforePayment + 10 ether,
            1000000000000000000
        );
        assertEq(uint256(escrow.getDeal(dealId).status), 1);
    }

    function testWithdraw() public {
        vm.roll(100);
        vm.prank(recruiter1);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        vm.prank(recruiter1);
        uint256 balanceBefore = token.balanceOf(address(recruiter1));
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );
        vm.warp(300);
        vm.prank(recruiter1);
        escrow.withdrawPayment(dealId);
        uint256 balanceAfter = token.balanceOf(address(recruiter1));
        assertEq(balanceAfter, balanceBefore);
    }

    function testWithdrawDownPayment() public {
        vm.roll(100);
        vm.prank(recruiter1);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            3 ether,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        vm.prank(recruiter1);
        uint256 balanceBefore = token.balanceOf(address(recruiter1));
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            3 ether,
            1,
            0,
            v,
            r,
            s
        );
        vm.warp(300);
        vm.prank(recruiter1);
        escrow.withdrawPayment(dealId);
        uint256 balanceAfter = token.balanceOf(address(recruiter1));
        assertEq(balanceAfter, balanceBefore);
    }

    function testWithdrawAfterClaim() public {
        vm.roll(100);
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        vm.prank(recruiter1);
        uint256 balanceBefore = token.balanceOf(address(recruiter1));
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );
        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 3 ether, 7, nftId);
        vm.prank(creator1);
        escrow.claimPayment(dealId, 1 ether, 10, nftId2);

        vm.prank(recruiter1);
        escrow.withdrawPayment(dealId);
        uint256 balanceAfter = token.balanceOf(address(recruiter1));
        assertEq(balanceAfter + 105e16, balanceBefore);
    }

    function testGrossRevenue() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 5 ether, 7, nftId);

        vm.prank(creator1);
        escrow.claimPayment(dealId, 5 ether, 10, nftId2);
        vm.prank(creator1);
        assertApproxEqAbs(
            token.balanceOf(address(creator1)),
            405 ether,
            300000000000000000
        );
        assertApproxEqAbs(
            registry.getNFTGrossRevenue(nftId2),
            5 ether,
            (10 ether * 6) / 100
        );
    }

    function testSuccessFee() public {
        escrow.changeSuccessFee(9);
        assertEq(escrow.successFee(), 9);
    }

    //function to test ClaimProfit
    function testClaimProfit() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );
        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);
        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 5 ether, 7, nftId);

        vm.prank(creator1);
        escrow.claimPayment(dealId, 5 ether, 10, nftId2);

        uint256 balanceBefore = token.balanceOf(address(deployer));
        vm.prank(deployer);
        escrow.claimProfit(dealId, address(deployer));
        assertApproxEqAbs(
            token.balanceOf(address(deployer)),
            balanceBefore + (5 ether * 5) / 100,
            1 ether / 1000
        );
    }

    //function to test ClaimProfits
    function testClaimProfits() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );

        vm.roll(100);
        vm.prank(recruiter2);
        token.approve(address(escrow), 12 ether);
        bytes32 message2 = sigUtils.getMessageHash(
            address(recruiter2),
            address(creator2),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage2 = sigUtils.getEthSignedMessageHash(message2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            creator2PrivateKey,
            hashedMessage2
        );
        vm.prank(recruiter2);
        uint256 dealId2 = escrow.createDeal(
            address(recruiter2),
            address(creator2),
            address(token),
            10 ether,
            0,
            1,
            0,
            v2,
            r2,
            s2
        );

        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);

        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 5 ether, 7, nftId);

        vm.prank(creator1);
        escrow.claimPayment(dealId, 5 ether, 10, nftId2);

        vm.prank(recruiter2);
        escrow.unlockPayment(dealId2, 5 ether, 7, nftId);

        vm.prank(creator2);
        escrow.claimPayment(dealId2, 5 ether, 10, nftId2);

        uint256 balanceBefore = token.balanceOf(address(deployer));
        vm.prank(deployer);
        escrow.claimProfits(address(deployer));
        assertApproxEqAbs(
            token.balanceOf(address(deployer)),
            balanceBefore + (10 ether * 5) / 100,
            1 ether / 1000
        );
    }

    //function to test GetDeal
    function testGetDeal() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );

        vm.roll(100);
        vm.prank(recruiter2);
        token.approve(address(escrow), 12 ether);
        bytes32 message2 = sigUtils.getMessageHash(
            address(recruiter2),
            address(creator2),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage2 = sigUtils.getEthSignedMessageHash(message2);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            creator2PrivateKey,
            hashedMessage2
        );
        vm.prank(recruiter2);
        uint256 dealId2 = escrow.createDeal(
            address(recruiter2),
            address(creator2),
            address(token),
            10 ether,
            0,
            1,
            0,
            v2,
            r2,
            s2
        );

        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);

        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 5 ether, 7, nftId);

        vm.prank(creator1);
        escrow.claimPayment(dealId, 5 ether, 10, nftId2);

        vm.warp(300);
        vm.prank(recruiter2);
        escrow.unlockPayment(dealId2, 5 ether, 7, nftId);

        vm.prank(creator2);
        escrow.claimPayment(dealId2, 3 ether, 10, nftId2);

        HWEscrow.Deal memory deal1 = escrow.getDeal(dealId);
        HWEscrow.Deal memory deal2 = escrow.getDeal(dealId2);

        assertEq(deal1.recruiter, address(recruiter1));
        assertEq(deal2.totalPayment, 10 ether);
        assertEq(deal2.claimedAmount, 3 ether);
    }

    //function to test getAvgCreatorRating
    function testAvgCreatorRating() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );

        uint256 nftId = hw721.tokenOfOwnerByIndex(address(creator1), 0);

        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 1 ether, 7, nftId);

        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 1 ether, 4, nftId);

        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 1 ether, 2, nftId);

        vm.warp(300);
        assertEq(escrow.getAvgCreatorRating(dealId), 433);
    }

    //function to test getAvgRecruiterRating
    function testAvgRecruiterRating() public {
        vm.roll(100);
        vm.prank(recruiter1);
        token.approve(address(escrow), 12 ether);
        bytes32 message = sigUtils.getMessageHash(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            0
        );
        bytes32 hashedMessage = sigUtils.getEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            creator1PrivateKey,
            hashedMessage
        );
        vm.prank(recruiter1);
        uint256 dealId = escrow.createDeal(
            address(recruiter1),
            address(creator1),
            address(token),
            10 ether,
            0,
            1,
            0,
            v,
            r,
            s
        );

        uint256 nftId = hw721.tokenOfOwnerByIndex(address(recruiter1), 0);
        uint256 nftId2 = hw721.tokenOfOwnerByIndex(address(creator1), 0);

        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 1 ether, 7, nftId2);

        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 1 ether, 4, nftId2);

        vm.prank(creator1);
        escrow.claimPayment(dealId, 1 ether, 10, nftId);

        vm.prank(creator1);
        escrow.claimPayment(dealId, 1 ether, 2, nftId);

        vm.warp(300);
        vm.prank(recruiter1);
        escrow.unlockPayment(dealId, 1 ether, 2, nftId2);

        assertEq(escrow.getAvgRecruiterRating(dealId), 600);
        assertEq(escrow.getAggregatedRating(recruiter1), 600);
    }
}
