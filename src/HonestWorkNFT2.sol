// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./Payments/HonestPayLock.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";



contract HonestWorkNFT2 is ERC721, ERC721Enumerable, Ownable {
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

    //@notice  2 1- tier1  2-tier2 3-tier3
    mapping(address => bool) public whitelistCap;
    mapping(uint256 => uint256) public tier;
    mapping(uint256 => uint256) public grossRevenue;

    HonestPayLock public honestPayLock;

    constructor() ERC721("HonestWork", "HW") {}

    function _baseURI() internal pure override returns (string memory) {
        return "AABDAF"; // HW URI
    }

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

    function recordGrossRevenue(uint256 _nftId, uint256  _revenue) external onlyHonestPay {
        grossRevenue[_nftId] += _revenue;
    }

    modifier onlyHonestPay{
        require(msg.sender == address(honestPayLock), "only HonestWork contract can record gross revenue");
        _;

    }

    function setHonestPayLock(HonestPayLock _honestPayLock) external onlyOwner {
        honestPayLock = _honestPayLock;
    }

        function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        require(balanceOf(to) == 0, "only one nft at a time");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
