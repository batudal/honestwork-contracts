// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract Verifier is Ownable {
//     bytes32 public root;


//     function verify(
//         bytes32[] memory proof,
//         address addr,
//         uint256 amount
//     ) public view returns(bool) {
//         bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(addr, amount))));
//         require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
//         return true;
//     }
//     //set Merkle root
//     function setRoot(bytes32 _root) external onlyOwner {
//         root = _root;
//     }
// }