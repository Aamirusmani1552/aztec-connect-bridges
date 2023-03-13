//SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {BridgeBase} from "../base/BridgeBase.sol";
import {AztecTypes} from "rollup-encoder/libraries/AztecTypes.sol";
import {NFTMarketplace} from "./MarketPlace.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ErrorLib} from "../base/ErrorLib.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {console} from "forge-std/console.sol";

error NFTBridge_InputNotAnNFT();
error NFTNotListed();
error NFTAlreadyBought();

contract NFTBridge is BridgeBase, IERC721Receiver {
    uint256 private id = 0;

    struct Asset {
        uint16 assetId;
        uint8 marketplaceId;
    }

    mapping(uint256 => Asset) public assetsByInteractionNonce;

    mapping(uint256 => address) public listedMarketplace;

    event log(NFTMarketplace.NFT nft);

    constructor(address _rollupProcessor) BridgeBase(_rollupProcessor) {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function listMarketPlace(address marketplace) public returns (uint256) {
        if (marketplace == address(0)) {
            revert ErrorLib.InvalidInput();
        }

        uint256 currentMarketplaceId = id++;
        listedMarketplace[currentMarketplaceId] = marketplace;
        return currentMarketplaceId;
    }

    function convert(
        AztecTypes.AztecAsset calldata _inputAssetA,
        AztecTypes.AztecAsset calldata,
        AztecTypes.AztecAsset calldata _outpuAssetA,
        AztecTypes.AztecAsset calldata,
        uint256 _totalAmount,
        uint256 _interactionNonce,
        uint64 _auxData,
        address
    ) external payable override(BridgeBase) onlyRollup returns (uint256, uint256, bool) {
        if (
            _inputAssetA.assetType == AztecTypes.AztecAssetType.VIRTUAL
                && _outpuAssetA.assetType == AztecTypes.AztecAssetType.NOT_USED
        ) {
            (uint16 assetId, uint8 marketplaceId, uint32 amount) = decodeDataWithThreeParams(_auxData);
            address marketplace = listedMarketplace[marketplaceId];

            IERC721 nft = IERC721(_inputAssetA.erc20Address);
            NFTMarketplace marketplaceContract = NFTMarketplace(marketplace);

            Asset memory newOwner = Asset({assetId: assetId, marketplaceId: marketplaceId});
            assetsByInteractionNonce[_interactionNonce] = newOwner;

            nft.safeTransferFrom(msg.sender, address(this), 0);
            nft.approve(marketplace, 0);
            marketplaceContract.listNFT(address(nft), assetId, amount * 10 ** 18);

            return (0, 0, false);
        } else if (
            _inputAssetA.assetType == AztecTypes.AztecAssetType.ETH
                && _outpuAssetA.assetType == AztecTypes.AztecAssetType.VIRTUAL
        ) {
            callForBuyNFT(_inputAssetA, _outpuAssetA, _interactionNonce, _auxData);
        }
    }

    function callForBuyNFT(
        AztecTypes.AztecAsset calldata _inputAssetA,
        AztecTypes.AztecAsset calldata _outpuAssetA,
        uint256 _interactionNonce,
        uint64 _auxData
    ) public payable {
        (uint16 tokenId, uint40 marketplaceId) = decodeDataWithTwoParams(_auxData);
        NFTMarketplace marketplace = NFTMarketplace(listedMarketplace[marketplaceId]);

        NFTMarketplace.NFT memory listedNFT = marketplace.getNFTListing(address(this), uint256(tokenId));

        if (listedNFT.owner == address(0)) {
            revert NFTNotListed();
        }

        if (listedNFT.buyer != address(0)) {
            revert NFTAlreadyBought();
        }

        marketplace.BuyNFT{value: msg.value}(tokenId, _outpuAssetA.erc20Address, address(this));

        // IERC721 nftContract = IERC721(_outpuAssetA.erc20Address);

        // nftContract.approve(ROLLUP_PROCESSOR, tokenId);
    }

    function encodeDataWithThreeParams(uint16 num1, uint8 num2, uint32 num3) public returns (uint64) {
        uint16 assetId = num1;
        uint8 marketplaceId = num2;
        uint32 amount = num3;
        uint64 auxData = (uint64(assetId) << 40 | uint64(marketplaceId) << 32 | uint64(amount));
        return auxData;
    }

    function decodeDataWithThreeParams(uint64 _num) public returns (uint16, uint8, uint32) {
        uint64 number = _num;

        uint16 a = uint16(number >> 40);
        uint8 b = uint8(number >> 32);
        uint32 c = uint32(number);

        return (a, b, c);
    }

    function encodeDateWithTwoParams(uint16 num1, uint32 num2) public returns (uint64) {
        uint16 assetId = num1;
        uint40 amount = num2;
        uint64 auxData = (uint64(assetId) << 40 | uint64(amount));

        return auxData;
    }

    function decodeDataWithTwoParams(uint64 _num) public returns (uint16, uint40) {
        uint64 number = _num;

        uint16 a = uint16(number >> 40);
        uint40 b = uint40(number);

        return (a, b);
    }

    fallback() external payable {}

    receive() external payable {}
}
