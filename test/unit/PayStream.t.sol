// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;
import {PayStreams} from "../../src/PayStream.sol";
import {initializeTokenAndActors} from "../utils/Helpers/initializeTokenAndActors.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {console } from "../../lib/forge-std/src/console.sol";
import {IPayStreams} from "../../src/interfaces/IPayStreams.sol";
import {MakeVaultforStreamer, MakeVaultforReceipient} from "../utils/MOCKS/makeVault.sol";
 import {makeHooks} from "../"

contract PayStream is Test, initializeTokenAndActors {
    MakeVaultforStreamer makeVaultForStreamer;
    MakeVaultforReceipient makeVaultForReceipient;
    PayStreams public payStreams;
    IPayStreams public iPayStreams;
    uint16 public basisPoint;
    function setUp() public {
        vm.startPrank(payStreamTeamAddress1);
        payStreams = new PayStreams(basisPoint);
        payStreams.setFeeInBasisPoints(10_000);
        vm.stopPrank();
    }

    function testIfBasisPointSetLower() public {
        vm.startPrank(payStreamTeamAddress1);
        vm.expectRevert();
        payStreams.setFeeInBasisPoints(15_000);
        vm.stopPrank();

       
    }
    function testBasisPoint() public view {
        uint16 basisPoint_ =  payStreams.getFeeInBasisPoints();
        assertEq(basisPoint_, 10_000);
    }

    function testSetToken() public {
        vm.startPrank(payStreamTeamAddress1);
        payStreams.setToken(address(mpyUSD), true);
        vm.stopPrank();
        bool isSupported = payStreams.isSupportedToken(address(mpyUSD));
        assertEq(isSupported, true);
    }
    modifier setSupportedToken() {
        vm.startPrank(payStreamTeamAddress1);
        payStreams.setToken(address(mpyUSD), true);
        vm.stopPrank();
        _;
    }

    function testCollectFee() public {
       // note this function is should be done after setVaultForStream function have been sorted out. 
       // get the streamData struct

    }

    function testSetStreamExpectRevert() public setSupportedToken {
        vm.startPrank(payStreamer);
        mpyUSD.mint(payStreamer, USDC10k );
        IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
            streamer: payStreamer,
            streamerVault: makeAddr("norevert"),
            recipient: payReceiver, 
            recipientVault: address(0),
            token: address(pyUSD),// the error is intentionally written in this line as pyUSD instead of mpyUSD
            amount: 1_000,
            startingTimestamp: block.timestamp,
            duration: 1 weeks,
            totalStreamed: 0,
            recurring: false
        });
        IPayStreams.HookConfig memory hookConfig = IPayStreams.HookConfig({
            callAfterStreamCreated:false,
            callBeforeFundsCollected: false,
            callAfterFundsCollected: false,
            callBeforeStreamUpdated: false,
            callAfterStreamUpdated: false,
            callBeforeStreamClosed: false,
            callAfterStreamClosed: false
        });

        string memory _tag = "HamidStream2";
        vm.expectRevert();
        payStreams.setStream(streamData, hookConfig, _tag);
        vm.stopPrank();
    }
    function testSetStream() public setSupportedToken {
        vm.startPrank(payStreamer);
        mpyUSD.mint(payStreamer, USDC10k);
        IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
            streamer: payStreamer,
            streamerVault: address(0),
            recipient: payReceiver, 
            recipientVault: address(0),
            token: address(mpyUSD),
            amount: 1_000,
            startingTimestamp: block.timestamp + 1 days,
            duration: 1 weeks,
            totalStreamed: 0,
            recurring: false
        });
        IPayStreams.HookConfig memory hookConfig = IPayStreams.HookConfig({
            callAfterStreamCreated:false,
            callBeforeFundsCollected: false,
            callAfterFundsCollected: false,
            callBeforeStreamUpdated: false,
            callAfterStreamUpdated: false,
            callBeforeStreamClosed: false,
            callAfterStreamClosed: false
        });

        string memory _tag = "HamidStream";
        console.log(streamData.streamerVault);
        bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);
        bytes32 expectedStreamHash = keccak256(abi.encode(payStreamer, payReceiver, address(mpyUSD), _tag));
        // console.log("this is the actual stream hash:", actualStreamHash);
        vm.assertEq(expectedStreamHash, actualStreamHash);
        vm.stopPrank();
    }

    function testSetVaultForStream() public setSupportedToken{
        // set Stream to update the mapping
        vm.startPrank(payStreamer);
        mpyUSD.mint(payStreamer, USDC10k );
        makeVaultForStreamer = new MakeVaultforStreamer(address(payStreamer));
        IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
            streamer: payStreamer,
            streamerVault: address(makeVaultForStreamer),
            recipient: payReceiver, 
            recipientVault: address(0),
            token: address(mpyUSD),
            amount: 1_000,
            startingTimestamp: block.timestamp,
            duration: 1 weeks,
            totalStreamed: 0,
            recurring: false
        });
        IPayStreams.HookConfig memory hookConfig = IPayStreams.HookConfig({
            callAfterStreamCreated:false,
            callBeforeFundsCollected: false,
            callAfterFundsCollected: false,
            callBeforeStreamUpdated: false,
            callAfterStreamUpdated: false,
            callBeforeStreamClosed: false,
            callAfterStreamClosed: false
        });

        string memory _tag = "HamidStream2";
        bytes32 streamHash = payStreams.setStream(streamData, hookConfig, _tag);
        vm.stopPrank();

        // create a streamer vault address 
        // makeVaultForStreamer = new MakeVaultforStreamer(address(payStreamer));
        vm.startPrank(payStreamer);
        payStreams.setVaultForStream(streamHash, address(makeVaultForStreamer));
        address expectedVault = payStreams.getStreamData(streamHash).streamerVault;
        address actualVault = address(makeVaultForStreamer);
        assertEq(expectedVault, actualVault);
        vm.stopPrank();
    }
    // note test feild waiting for update from sahil.
    function  testSetVaultForReceiver() public setSupportedToken{
        vm.startPrank(payStreamer);
        mpyUSD.mint(payStreamer, USDC10k );
        makeVaultForReceipient = new MakeVaultforReceipient(address(payReceiver));
        IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
            streamer: payStreamer,
            streamerVault: address(0),
            recipient: payReceiver, 
            recipientVault: address(makeVaultForReceipient),
            token: address(mpyUSD),
            amount: 1_000,
            startingTimestamp: block.timestamp,
            duration: 1 weeks,
            totalStreamed: 0,
            recurring: false
        });
        IPayStreams.HookConfig memory hookConfig = IPayStreams.HookConfig({
            callAfterStreamCreated:false,
            callBeforeFundsCollected: false,
            callAfterFundsCollected: false,
            callBeforeStreamUpdated: false,
            callAfterStreamUpdated: false,
            callBeforeStreamClosed: false,
            callAfterStreamClosed: false
        });

        string memory _tag = "HamidStream2";
        bytes32 streamHash = payStreams.setStream(streamData, hookConfig, _tag);
        vm.stopPrank();

        // create a streamer vault address 
        vm.startPrank(payReceiver);
        payStreams.setVaultForStream(streamHash, address(makeVaultForReceipient));
        address expectedVault = payStreams.getStreamData(streamHash).recipientVault;
        address actualVault = address(makeVaultForReceipient);
        assertEq(expectedVault, actualVault);
        vm.stopPrank();
    }

    function testSetHookConfigForStream() public setSupportedToken {
        vm.startPrank(payStreamer);
        mpyUSD.mint(payStreamer, USDC10k);
        IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
            streamer: payStreamer,
            streamerVault: address(0),
            recipient: payReceiver, 
            recipientVault: address(0),
            token: address(mpyUSD),
            amount: 1_000,
            startingTimestamp: block.timestamp + 1 days,
            duration: 1 weeks,
            totalStreamed: 0,
            recurring: false
        });
        IPayStreams.HookConfig memory hookConfig = IPayStreams.HookConfig({
            callAfterStreamCreated:false,
            callBeforeFundsCollected: false,
            callAfterFundsCollected: false,
            callBeforeStreamUpdated: false,
            callAfterStreamUpdated: false,
            callBeforeStreamClosed: false,
            callAfterStreamClosed: false
        });

        string memory _tag = "HamidStream";
        console.log(streamData.streamerVault);
        bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);
        bytes32 expectedStreamHash = keccak256(abi.encode(payStreamer, payReceiver, address(mpyUSD), _tag));
        // console.log("this is the actual stream hash:", actualStreamHash);
        vm.assertEq(expectedStreamHash, actualStreamHash);
        vm.stopPrank();
    }
}
