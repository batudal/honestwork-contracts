// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/utils/MockToken.sol";
import "../src/StarterNFT.sol";
import "../src/utils/Merkle.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract StarterNFTTest is Test, MerkleUtils {
    string public baseuri = "https://api.honestwork.app/metadata/starter/";
    string public single_asset_uri =
        "https://api.honestwork.app/metadata/starter/1";
    MockToken public mocktoken;
    StarterNFT public starterNFT;
    address public zero = 0x0000000000000000000000000000000000000000;
    uint256 public mock_amount = 50000 ether;
    uint256 public basefee = 10000000;
    uint256 public ambassador_percentage = 10;
    address public takezo = 0xfB1C2FF46962B452C1731d44F0789bFb3607e63f;
    uint256 minted = 0;

    function setUp() public {
        mocktoken = new MockToken("MCK", "MOCK");
        assertEq(mocktoken.balanceOf(address(this)), mock_amount);
        starterNFT = new StarterNFT(
            baseuri,
            address(mocktoken),
            basefee,
            ambassador_percentage
        );
        assertEq(starterNFT.tokenURI(42), single_asset_uri);
        minted++;
    }

    function testURIToggle() public {
        starterNFT.setSingleAsset(false);
        assertEq(
            starterNFT.tokenURI(42),
            "https://api.honestwork.app/metadata/starter/42"
        );
    }

    function testMint() public {
        (address token, uint256 fee, ) = starterNFT.payment();
        IERC20(token).approve(address(starterNFT), fee);
        starterNFT.mint();
        assertEq(starterNFT.balanceOf(address(this)), 2);
        assertEq(IERC20(token).balanceOf(address(this)), mock_amount - fee);
        assertEq(IERC20(token).balanceOf(address(starterNFT)), fee);
    }

    function testPause() public {
        starterNFT.pause();
        (, uint256 fee, ) = starterNFT.payment();
        mocktoken.approve(address(starterNFT), fee);
        vm.expectRevert();
        starterNFT.mint();
    }

    function testWithdraw() public {
        (address token, uint256 fee, ) = starterNFT.payment();
        IERC20(token).approve(address(starterNFT), fee);
        starterNFT.mint();
        assertEq(IERC20(token).balanceOf(address(starterNFT)), fee);
        starterNFT.withdraw();
        assertEq(IERC20(token).balanceOf(address(this)), mock_amount);
        assertEq(IERC20(token).balanceOf(address(starterNFT)), 0);
    }

    function testAmbassadorMintClaim() public {
        bytes32[] memory ambassadors = new bytes32[](2);
        ambassadors[0] = keccak256(abi.encodePacked(address(this)));
        ambassadors[1] = keccak256(abi.encodePacked(address(takezo)));
        bytes32 root = getRoot(ambassadors);
        starterNFT.setWhitelistRoot(root);
        bytes32[] memory proof = getProof(ambassadors, 0);
        assertTrue(MerkleProof.verify(proof, root, ambassadors[0]));
        (address token, uint256 fee, uint256 percentage) = starterNFT.payment();
        IERC20(token).approve(address(starterNFT), fee);
        starterNFT.ambassadorMint(address(this), proof);
        assertEq(starterNFT.balanceOf(address(this)), 2);
        starterNFT.withdraw();
        assertEq(
            IERC20(token).balanceOf(address(starterNFT)),
            (fee * percentage) / 100
        );
        starterNFT.ambassadorClaim();
        assertEq(IERC20(token).balanceOf(address(starterNFT)), 0);
    }

    function testSetPayment() public {
        uint256 multiplier = 2;
        (address token, uint256 fee, uint256 percentage) = starterNFT.payment();
        starterNFT.setPayment(
            address(token),
            fee * multiplier,
            percentage * multiplier
        );
        IERC20(token).approve(address(starterNFT), fee * multiplier);
        starterNFT.mint();
        minted++;
        console.log("minted", minted);
        assertEq(
            IERC20(token).balanceOf(address(starterNFT)),
            fee * (minted - 1) * multiplier
        );
        bytes32[] memory ambassadors = new bytes32[](2);
        ambassadors[0] = keccak256(abi.encodePacked(address(this)));
        ambassadors[1] = keccak256(abi.encodePacked(address(takezo)));
        bytes32 root = getRoot(ambassadors);
        starterNFT.setWhitelistRoot(root);
        bytes32[] memory proof = getProof(ambassadors, 0);
        assertTrue(MerkleProof.verify(proof, root, ambassadors[0]));
        IERC20(token).approve(address(starterNFT), fee * multiplier);
        starterNFT.ambassadorMint(address(this), proof);
        minted++;
        assertEq(starterNFT.balanceOf(address(this)), minted);
        assertEq(
            IERC20(token).balanceOf(address(starterNFT)),
            fee * (minted - 1) * multiplier
        );
        starterNFT.withdraw();
        assertEq(
            IERC20(token).balanceOf(address(starterNFT)),
            (fee * (multiplier**2) * percentage) / 100
        );
    }
}
