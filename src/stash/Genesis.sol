// /**
//  * @author  Decoded Labs.
//  * @title   NFT implementation for HonestWork.
//  * @dev     @takez0_o, @0xRedKidd.

//  */


// pragma solidity ^0.8.6;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";



// contract Genesis is ERC721 {
    
//     mapping(uint256 => uint256) nftState;
//     Counters.Counter private _tokenIds;
//     address public owner;

//     constructor(
//         string memory _name,
//         string memory _symbol
//     ) ERC721(_name, _symbol) {
//         owner = msg.sender;
//     }

//     // free
//     function bind(uint256 _Id) external returns(bool) {
//         require(ownerOf(_Id) == msg.sender, "you are not the owner of the specified NFT");
//         nftState[_Id] = 2;
//         return true;
//     }

//     // pay
//     function mint(address _to) external {
//         _tokenIds.increment();        
//         uint256 newItemId = _tokenIds.current();
//         _mint(_to, newItemId);

//         userState[msg.sender] = 1;
//     }

//     function getUserState(address _user) public view returns (uint256) {
//         return userState[_user];
//     }

//     function _beforeTokenTransfer(
//         address from,
//         address to,
//         uint256 id,
//         uint256 batchSize
//     ) internal virtual override {
        
//         super._beforeTokenTransfer(from, to, id, batchSize);
//     }

//     function verifyCalldata(
//     bytes32[] calldata proof,
//     bytes32 root,
//     bytes32 leaf
// ) internal pure returns (bool) {
//     return processProofCalldata(proof, leaf) == root;
// }

// function processProofCalldata(
//     bytes32[] calldata proof,
//     bytes32 leaf
// ) internal pure returns (bytes32) {
//     bytes32 computedHash = leaf;
//     for (uint256 i = 0; i < proof.length; i++) {
//         computedHash = _hashPair(computedHash, proof[i]);
//     }
//     return computedHash;
// }

// function _hashPair(bytes32 a, bytes32 b)
//     private
//     pure
//     returns(bytes32)
// {
//     return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
// }

// function _efficientHash(bytes32 a, bytes32 b)
//     private
//     pure
//     returns (bytes32 value)
// {
//     assembly {
//         mstore(0x00, a)
//         mstore(0x20, b)
//         value := keccak256(0x00, 0x40)
//     }
// }
// }