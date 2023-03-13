//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";

import {NFTMarketplace} from "../../../bridges/MyBridge1/MarketPlace.sol";
import {MyNFT} from "../../../bridges/MyBridge1/NFT.sol";
import {BridgeTestBase} from "./../../aztec/base/BridgeTestBase.sol";
import {AztecTypes} from "rollup-encoder/libraries/AztecTypes.sol";
import {NFTBridge} from "../../../bridges/MyBridge1/NFTBridge.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTMarketplaceBridge is BridgeTestBase, IERC721Receiver {
    NFTMarketplace public nftMarketplace;
    MyNFT public nft;

    NFTBridge public bridge;

    address public player = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public deployer = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public buyer = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public {
        bridge = new NFTBridge(address(this));

        vm.startPrank(deployer);
        nftMarketplace = new NFTMarketplace(address(bridge));
        vm.stopPrank();
        vm.deal(address(nftMarketplace), 1 ether);

        vm.startPrank(player);
        nft = new MyNFT();
        nft.safeTransferFrom(player, address(this), 0);
        vm.stopPrank();

        bridge.listMarketPlace(address(nftMarketplace));

        nft.approve(address(bridge), 0);
    }

    function test_listNFT() public {
        // listing nft
        AztecTypes.AztecAsset memory inputAsset =
            AztecTypes.AztecAsset({id: 3, erc20Address: address(nft), assetType: AztecTypes.AztecAssetType.VIRTUAL});
        uint64 auxData = encodeDataWithThreeParams(0, 0, 2);
        bridge.convert(inputAsset, emptyAsset, emptyAsset, emptyAsset, 0, 0, auxData, address(0));

        NFTMarketplace.NFT memory nftToken = nftMarketplace.getNFTListing(address(bridge), 0);

        assertEq(nftToken.owner, address(bridge));
        console.log(nftToken.owner);

        // buying nft
        AztecTypes.AztecAsset memory inputAsset2 =
            AztecTypes.AztecAsset({id: 1, erc20Address: address(0), assetType: AztecTypes.AztecAssetType.ETH});

        AztecTypes.AztecAsset memory outputAsset =
            AztecTypes.AztecAsset({id: 3, erc20Address: address(nft), assetType: AztecTypes.AztecAssetType.VIRTUAL});

        uint64 auxData2 = encodeDateWithTwoParams(0, 0);

        vm.deal(address(this), 10 ether);
        bridge.convert{value: 2 ether, gas: 30000000}(
            inputAsset2, emptyAsset, outputAsset, emptyAsset, 2 ether, 0, auxData2, address(0)
        );
    }

    function encodeDataWithThreeParams(uint16 num1, uint8 num2, uint32 num3) public returns (uint64) {
        uint16 assetId = num1;
        uint8 marketplaceId = num2;
        uint32 amount = num3;
        uint64 auxData = (uint64(assetId) << 40 | uint64(marketplaceId) << 32 | uint64(amount));
        return auxData;
    }

    function encodeDateWithTwoParams(uint16 num1, uint32 num2) public returns (uint64) {
        uint16 assetId = num1;
        uint40 marketplaceId = num2;
        uint64 auxData = (uint64(assetId) << 40 | uint64(marketplaceId));

        return auxData;
    }

    fallback() external payable {}

    receive() external payable {}
}
