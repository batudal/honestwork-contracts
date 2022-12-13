//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

//push deneme

contract HonestWorkNFT is Ownable, ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;
    //TBD
    uint256 public MINT_FEE = 10 ether;

    uint256 public constant TOKEN_CAP = 10000;
    // TBD
    uint256 public tier2Fee = 100 ether;
    //TBD
    uint256 public tier3Fee = 1000 ether;
    bytes32 public whitelistRoot;
    mapping(address => bool) public whitelistCap;

    //@notice  2 1- tier1  2-tier2 3-tier3
    mapping(uint256 => uint256) public tier;
    mapping(uint256 => bool) public soulbound;

    constructor() ERC721("HonestWork", "HW") {}

    function publicMint(address recipient) external payable returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(msg.value > MINT_FEE, "not enough funds");
        require(newItemId < TOKEN_CAP, "all the nfts are claimed");
        _mint(recipient, newItemId);
        tier[newItemId] = 1;
        soulbound[newItemId] = false;

        return newItemId;
    }

    function whitelistMint(address recipient, bytes32[] calldata _proof)
        external
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(newItemId < TOKEN_CAP, "all the nfts are claimed");
        require(
            _verify(_whitelistLeaf(msg.sender), whitelistRoot, _proof),
            "Invalid merkle proof"
        );

        whitelistCap[msg.sender] = true;
        _mint(recipient, newItemId);
        tier[newItemId] = 1;
        soulbound[newItemId] = false;

        return newItemId;
    }

    function bindToken(uint256 _tokenId) external {
        require(
            ownerOf(_tokenId) == msg.sender,
            "only owned tokens can be claimed"
        );
        soulbound[_tokenId] = true;
    }

    function unbindToken(uint256 _tokenId) external {
        require(
            ownerOf(_tokenId) == msg.sender,
            "only owned tokens can be disclaimed"
        );
        soulbound[_tokenId] = false;
    }

    function upgradeToken(uint256 _tokenId, uint256 _tier) external payable {
        require(
            ownerOf(_tokenId) == msg.sender,
            "only owned tokens can be claimed"
        );
        if (_tier == 2) {
            require(msg.value > tier2Fee);
        } else if (_tier == 3) {
            require(msg.value > tier3Fee);
        } else {
            revert("only 3 tiers possible");
        }
        tier[_tokenId] = _tier;
    }

    function _whitelistLeaf(address _address) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_address));
    }

    function _verify(
        bytes32 leaf,
        bytes32 _root,
        bytes32[] memory _proof
    ) internal pure returns (bool) {
        return MerkleProof.verify(_proof, _root, leaf);
    }

    function setWhitelistRoot(bytes32 _root) external onlyOwner {
        whitelistRoot = _root;
    }

    function changeTierTwoFee(uint256 _newFee) external onlyOwner {
        tier2Fee = _newFee;
    }

    function changeTierThreeFee(uint256 _newFee) external onlyOwner {
        tier3Fee = _newFee;
    }
}
