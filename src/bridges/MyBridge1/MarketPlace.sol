//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NFTMarketplace_CallerNotOwner();
error NFTMarketplace_InsufficientFunds();
error NFTMarketplace_AlreadyOwner();
error NFTMarketplace_AmountLessThanEqualZero();
error NFTMarketplace_InvalidTokenId();
error NFTMarketplace_AddressZeroProvided();
error NFTMarketplace_AlreadyBought();
error NFTMarketplace_SomethingWentWrong();
error NFTMarketplace_NFTNotListed();

contract NFTMarketplace is IERC721Receiver, ReentrancyGuard {
    struct NFT {
        address nftAddress;
        uint256 tokenId;
        address owner;
        uint256 listingTime;
        address buyer;
        uint256 price;
    }

    mapping(address => mapping(uint256 => NFT)) public nftsForListing;

    event NFTBought(address indexed buyer, address indexed owner, uint256 price, uint256 indexed tokenId);

    constructor() {}

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        override
        nonReentrant
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    function listNFT(address _nftAddress, uint16 _tokenId, uint256 _amount) public {
        if (_amount <= 0) {
            revert NFTMarketplace_AmountLessThanEqualZero();
        }
        IERC721 nft = IERC721(_nftAddress);

        if (nft.ownerOf(_tokenId) != msg.sender) {
            revert NFTMarketplace_CallerNotOwner();
        }

        NFT memory newNFT = NFT(_nftAddress, _tokenId, msg.sender, block.timestamp, address(0), _amount);

        nftsForListing[msg.sender][_tokenId] = newNFT;
        nft.safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    function BuyNFT(uint256 _tokenId, address _nftAddress) public payable nonReentrant {
        if (_tokenId < 0) {
            revert NFTMarketplace_InvalidTokenId();
        }

        IERC721 nft = IERC721(_nftAddress);
        NFT memory listedNFT = nftsForListing[nft.ownerOf(_tokenId)][_tokenId];

        if (listedNFT.owner == msg.sender) {
            revert NFTMarketplace_AlreadyOwner();
        }

        if (listedNFT.buyer != address(0)) {
            revert NFTMarketplace_AlreadyBought();
        }

        if (msg.value == 0) {
            revert NFTMarketplace_AmountLessThanEqualZero();
        }

        if (listedNFT.price > msg.value) {
            revert NFTMarketplace_InsufficientFunds();
        }

        if (_nftAddress == address(0)) {
            revert NFTMarketplace_AddressZeroProvided();
        }

        listedNFT.buyer = msg.sender;
        nft.safeTransferFrom(address(this), msg.sender, _tokenId);

        (bool success,) = payable(listedNFT.owner).call{value: msg.value}("");
        if (!success) {
            revert NFTMarketplace_SomethingWentWrong();
        }

        emit NFTBought(msg.sender, listedNFT.owner, msg.value, listedNFT.tokenId);
    }

    function removeListing(uint256 _tokenId, address _nftAddress) public {
        if (_nftAddress == address(0)) {
            revert NFTMarketplace_AddressZeroProvided();
        }

        IERC721 nft = IERC721(_nftAddress);
        address currentOwner = nft.ownerOf(_tokenId);

        if (currentOwner != address(this)) {
            revert NFTMarketplace_NFTNotListed();
        }

        NFT storage nftToRemove = nftsForListing[nft.ownerOf(_tokenId)][_tokenId];

        if (nftToRemove.owner != msg.sender) {
            revert NFTMarketplace_CallerNotOwner();
        }

        if (nftToRemove.buyer != address(this)) {
            revert NFTMarketplace_AlreadyBought();
        }

        nft.safeTransferFrom(address(this), msg.sender, nftToRemove.tokenId);

        delete nftsForListing[msg.sender][_tokenId];
    }

    function getNFTListing(address owner, uint256 tokenId) public view returns (NFT memory) {
        return nftsForListing[owner][tokenId];
    }
}
