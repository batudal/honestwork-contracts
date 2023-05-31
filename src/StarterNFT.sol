// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title HonestWork Starter NFT
/// @author @takez0_o
/// @notice Starter Membership NFT's to be used in the platform
contract StarterNFT is ERC721, Ownable {
    struct Payment {
        address token;
        uint256 amount;
    }
    string public baseuri;
    uint256 public cap = 10000;
    uint256 public id = 1;
    bool public paused = false;
    bool public single_asset = true;
    Payment public payment;

    event Mint(uint256 id, address user);

    constructor(
        string memory _baseuri,
        address _token,
        uint256 _amount
    ) ERC721("HonestWork Starter", "HWS") {
        baseuri = _baseuri;
        payment = Payment(_token, _amount);
        _mint(msg.sender, 0);
    }

    //-----------------//
    //  admin methods  //
    //-----------------//

    function setBaseUri(string memory _baseuri) external onlyOwner {
        baseuri = _baseuri;
    }

    function setCap(uint256 _cap) external onlyOwner {
        cap = _cap;
    }

    function setSingleAsset(bool _single_asset) external onlyOwner {
        single_asset = _single_asset;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function setPayment(address _token, uint256 _amount) external onlyOwner {
        payment = Payment(_token, _amount);
    }

    function withdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function withdraw(address _token) external onlyOwner {
        IERC20(_token).transfer(
            msg.sender,
            IERC20(_token).balanceOf(address(this))
        );
    }

    function withdraw() external onlyOwner {
        IERC20(payment.token).transfer(
            msg.sender,
            IERC20(payment.token).balanceOf(address(this))
        );
    }

    //--------------------//
    //  internal methods  //
    //--------------------//

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

    //--------------------//
    //  mutative methods  //
    //--------------------//

    function mint() external whenNotPaused {
        require(id < cap, "cap reached");
        IERC20(payment.token).transferFrom(
            msg.sender,
            address(this),
            payment.amount
        );
        _mint(msg.sender, id);
        emit Mint(id, msg.sender);
        id++;
    }

    //----------------//
    //  view methods  //
    //----------------//

    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(ERC721)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }

    function tokenURI(uint256 _tokenid)
        public
        view
        override
        returns (string memory)
    {
        if (single_asset) {
            return string(abi.encodePacked(baseuri, "1"));
        } else {
            return string(abi.encodePacked(baseuri, _toString(_tokenid)));
        }
    }

    //----------------//
    //   modifiers    //
    //----------------//

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
}
