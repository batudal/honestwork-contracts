// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Registry/IHWRegistry.sol";
import "./utils/Base64.sol";

contract HonestWorkNFT is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public _tokenIds;
    bytes32 public whitelistRoot;
    IHWRegistry public registry;
    address public honestPayLock;
    address public metadataImplementation;

    uint256 public constant TOKEN_CAP = 1000;
    uint256 public tierOneFee = 100 ether;
    uint256 public tierTwoFee = 250 ether;
    uint256 public tierThreeFee = 300 ether;
    string[] private revenueTiers = [
        "< $1000",
        "$1000 - $10,000",
        "$10,000 - $100,000",
        "HonestChad"
    ];
    uint256[] private revenueThresholds = [1000e18, 10000e18, 100000e18];

    mapping(address => bool) public whitelistCap;
    mapping(uint256 => uint256) public tier;
    mapping(uint256 => uint256) public grossRevenue;

    event RevenueIncrease(uint256 id, uint256 revenue);
    event Upgrade(uint256 id, uint256 tier);
    event Mint(uint256 id, address user);

    constructor(
        address _registry
    ) ERC721("HonestWork Genesis", "HonestWork Genesis") {
        registry = IHWRegistry(_registry);
    }

    modifier onlyHonestPay() {
        require(
            msg.sender == honestPayLock,
            "only HonestWork contract can record gross revenue"
        );
        _;
    }

    // restricted fxns

    function setWhitelistRoot(bytes32 _root) external onlyOwner {
        whitelistRoot = _root;
    }

    function recordGrossRevenue(
        uint256 _nftId,
        uint256 _revenue
    ) external onlyHonestPay {
        grossRevenue[_nftId] += _revenue;
        emit RevenueIncrease(_nftId, _revenue);
    }

    function setHonestPayLock(address _honestPayLock) external onlyOwner {
        honestPayLock = _honestPayLock;
    }

    // view fxns

    function getGrossRevenue(uint256 _tokenId) external view returns (uint256) {
        return grossRevenue[_tokenId];
    }

    function getAllGrossRevenues() external view returns (uint256[] memory) {
        uint256[] memory _grossRevenues = new uint256[](totalSupply());
        for (uint256 i = 0; i < totalSupply(); i++) {
            _grossRevenues[i] = grossRevenue[i];
        }
        return _grossRevenues;
    }

    function supportsInterface(
        bytes4 _interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function getRevenueTier(
        uint256 _tokenId
    ) public view returns (string memory) {
        uint256 rev = grossRevenue[_tokenId];
        if (rev < revenueThresholds[0]) {
            return revenueTiers[0];
        } else if (rev < revenueThresholds[1]) {
            return revenueTiers[1];
        } else if (rev < revenueThresholds[2]) {
            return revenueTiers[2];
        } else return revenueTiers[3];
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "HonestWork Genesis #',
                        _toString(_tokenId),
                        '", "description": "HonestWork Genesis NFTs are the gateway to HonestWork ecosystem.",',
                        '"image": "https://honestwork-userfiles.fra1.cdn.digitaloceanspaces.com/genesis-nft/',
                        _toString(_tokenId),
                        '.png", "external_url": "https://honestwork.app",',
                        '"attributes": [ { "trait_type": "Tier", "value": ',
                        _toString(tier[_tokenId]),
                        ', "max_value":3 }, { "trait_type": "Gross Revenue ($)", "value": ',
                        _toString(grossRevenue[_tokenId] / 1e18),
                        '}, { "trait_type": "Revenue Tier", "value": "',
                        getRevenueTier(_tokenId),
                        '" }]}'
                    )
                )
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
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
        require(
            registry.isAllowedAmount(_token, tierOneFee),
            "token not allowed"
        );
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
        address _token,
        bytes32[] calldata _proof
    ) external returns (uint256) {
        require(
            registry.isAllowedAmount(_token, tierOneFee),
            "token not allowed"
        );
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

    function upgradeToken(uint256 _levels) external payable {
        require(_levels == 1 || _levels == 2);
        require(balanceOf(msg.sender) == 1);
        uint256 _tokenId = tokenOfOwnerByIndex(msg.sender, 0);
        require(tier[_tokenId] != 3);
        if (_levels == 2) {
            require(tier[_tokenId] == 1);
            tier[_tokenId] += 2;
        } else {
            tier[_tokenId]++;
        }

        emit Upgrade(_tokenId, tier[_tokenId]);
    }

    function setRevenueTiers(
        string[] memory _revenueTiers,
        uint256[] memory _revenueThresholds
    ) external onlyOwner {
        revenueTiers = _revenueTiers;
        revenueThresholds = _revenueThresholds;
    }
}
