// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Registry/HWRegistry.sol";
import "./utils/Base64.sol";

contract HonestWorkNFT is ERC721, ERC721Enumerable, Ownable, HWRegistry {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;
    bytes32 public whitelistRoot;
    uint256 public constant TOKEN_CAP = 1001;
    uint256 public tierOneFee = 100e18;
    uint256 public tierTwoFee = 250e18;
    uint256 public tierThreeFee = 300e18;

    mapping(address => bool) public whitelistCap;
    mapping(uint256 => uint256) public tier;

    event Upgrade(uint256 id, uint256 tier);
    event Mint(uint256 id, address user);

    constructor() ERC721("HonestWork Genesis", "HonestWork Genesis") {}

    // restricted fxns
    function setWhitelistRoot(bytes32 _root) external onlyOwner {
        whitelistRoot = _root;
    }

    function withdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function adminMint(address _to, uint256 _tier) external onlyOwner {
        require(_tokenIds.current() < TOKEN_CAP, "Token cap reached");
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(_to, newTokenId);
        tier[newTokenId] = _tier;
        emit Mint(newTokenId, _to);
    }

    function supportsInterface(
        bytes4 _interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function tokenURI(
        uint256 _tokenId
    ) public pure override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "https://api.honestwork.app/nft/",
                    _toString(_tokenId)
                )
            );
    }

    // internal fxns

    function _whitelistLeaf(address _address) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_address));
    }

    function _verify(
        bytes32 _leaf,
        bytes32 _root,
        bytes32[] memory _proof
    ) internal pure returns (bool) {
        return MerkleProof.verify(_proof, _root, _leaf);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        require(balanceOf(_to) == 0, "only one nft at a time");
        super._beforeTokenTransfer(_from, _to, _tokenId, _batchSize);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // mutative fxns

    function publicMint(address _token) external returns (uint256) {
        require(isAllowedAmount(_token, tierOneFee), "token not allowed");
        IERC20(_token).transferFrom(msg.sender, address(this), tierOneFee);
        uint256 newItemId = _tokenIds.current();
        require(newItemId < TOKEN_CAP, "all the nfts are claimed");
        _mint(msg.sender, newItemId);
        tier[newItemId] = 1;
        _tokenIds.increment();
        emit Mint(newItemId, msg.sender);
        return newItemId;
    }

    function whitelistMint(
        bytes32[] calldata _proof
    ) external returns (uint256) {
        require(!whitelistCap[msg.sender], "whitelist cap reached");
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(newItemId < TOKEN_CAP, "all the nfts are claimed");
        require(
            _verify(_whitelistLeaf(msg.sender), whitelistRoot, _proof),
            "Invalid merkle proof"
        );

        whitelistCap[msg.sender] = true;
        _mint(msg.sender, newItemId);
        tier[newItemId] = 1;

        return newItemId;
    }

    function upgradeToken(address _token, uint256 _levels) external {
        require(_levels == 1 || _levels == 2);
        require(balanceOf(msg.sender) == 1);
        uint256 _tokenId = tokenOfOwnerByIndex(msg.sender, 0);
        require(tier[_tokenId] != 3);
        if (_levels == 2) {
            require(tier[_tokenId] == 1);
            tier[_tokenId] += 2;
            require(isAllowedAmount(_token, tierTwoFee), "token not allowed");
            IERC20(_token).transferFrom(msg.sender, address(this), tierTwoFee);
        } else {
            tier[_tokenId]++;
            require(isAllowedAmount(_token, tierOneFee), "token not allowed");
            IERC20(_token).transferFrom(msg.sender, address(this), tierOneFee);
        }
        emit Upgrade(_tokenId, tier[_tokenId]);
    }
}
