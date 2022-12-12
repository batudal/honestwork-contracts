//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract HonestWorkNFT is Ownable, ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    uint256 public constant MINT_FEE = 10 ether;
    uint256 public constant TOKEN_CAP = 10000;
    uint256 public TIER2_FEE = 100 ether;
    uint256 public TIER3_FEE = 1000 ether;
    bytes32 public whitelistRoot;
    mapping(address => bool) public whitelistCap;

    //@notice 1-not soulbound, 2-soulbound-tier1 3-soulbound-tier2 4-soulbound-tier3
    mapping(uint256 => uint256) public tier;

    constructor() ERC721("HonestWork", "HW") {}

    function publicMint(address recipient) external payable returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(msg.value > MINT_FEE, "not enough funds");
        require(newItemId < TOKEN_CAP, "all the nfts are claimed");
        _mint(recipient, newItemId);
        tier[newItemId] = 1;

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

        return newItemId;
    }

    function bindToken(uint256 _tokenId) external {
        require(
            ownerOf(_tokenId) == msg.sender,
            "only owned tokens can be claimed"
        );
        tier[_tokenId] = 2;
    }

    function upgradeToken(uint256 _tokenId, uint256 _tier) external payable {
        require(
            ownerOf(_tokenId) == msg.sender,
            "only owned tokens can be claimed"
        );
        if (_tier == 3) {
            require(msg.value > TIER2_FEE);
        } else if (_tier == 4) {
            require(msg.value > TIER3_FEE);
        } else {
            revert();
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
}
