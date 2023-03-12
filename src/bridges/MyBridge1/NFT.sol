// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyNFT is ERC721 {
    string private constant TOKEN_URI =
        "https://ipfs.io/ipfs/QmWfidESYC6iJNQYVfUR37hoBP7Nx8UpXqbAsB1Bbutb2q/";

    constructor() ERC721("MyNFT", "APE") {
        _safeMint(msg.sender, 0);
    }

    function tokenURI(
        uint256 tokenId
    ) public pure override returns (string memory) {
        return TOKEN_URI;
    }
}
