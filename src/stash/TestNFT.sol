// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {
    mapping(address => uint256) userState;
    uint256 counter;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        _mint(msg.sender, counter);
        counter++;
    }

    // free
    function bind() public {
        require(balanceOf(msg.sender) == 1);
        require(userState[msg.sender] < 2);
        userState[msg.sender] = 2;
    }

    // pay
    function tier() public {
        require(userState[msg.sender] < 4);
        userState[msg.sender]++;
    }

    // pay
    function mint() public {
        _mint(msg.sender, counter);
        userState[msg.sender] = 1;
        counter++;
    }

    // pay
    function invite(address _to) public {
        _mint(_to, counter);
        userState[_to] = 2;
        counter++;
    }

    // 0-no tokens, 1-not soulbound, 2-soulbound(tier 1), 3-soulbound(tier 2), 4-soulbound(tier-3)
    function getUserState(address _user) public view returns (uint256) {
        return userState[_user];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 id,
        uint256 batchSize
    ) internal virtual override {
        if (from == address(0)) {
            require(balanceOf(to) == 0, "1 per wallet");
        } else if (to != address(0)) {
            require(userState[from] < 2, "Your token is bounded");
            require(balanceOf(to) == 0, "Receiver already has a token");
        }
        super._beforeTokenTransfer(from, to, id, batchSize);
    }
}
