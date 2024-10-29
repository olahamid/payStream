// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;
import {PayStreams} from "../../src/PayStream.sol";
import {initializeTokenAndActors} from "../utils/Helpers/initializeTokenAndActors.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {console } from "../../lib/forge-std/src/console.sol";
import {IPayStreams} from "../../src/interfaces/IPayStreams.sol";
import {MakeVaultforStreamer} from "../utils/MOCKS/makeVault.sol";
import { MakeVaultforReceipient} from "../utils/MOCKS/makeValt2.sol";
import {MakeHook} from "../../test/utils/MOCKS/makeHooks.sol";

contract PayStream is Test, initializeTokenAndActors {
    MakeVaultforStreamer makeVaultForStreamer;
    MakeVaultforReceipient makeVaultForReceipient;
    MakeHook makeHook;
    PayStreams public payStreams;
    IPayStreams public iPayStreams;
    uint16 public basisPoint;
    function setUp() public {
        vm.startPrank(payStreamTeamAddress1);
        payStreams = new PayStreams(basisPoint);
        payStreams.setFeeInBasisPoints(5_00);
        vm.stopPrank();
    }

    function testIfBasisPointSetLower() public {
        vm.startPrank(payStreamTeamAddress1);
        vm.expectRevert();
        payStreams.setFeeInBasisPoints(15_000);
        vm.stopPrank(); 
    }
    function testBasisPoint() public {
        uint16 newBasisPoint = 200;
        vm.startPrank(payStreamTeamAddress1);
        payStreams.setFeeInBasisPoints(newBasisPoint);
        uint16 basisPoint_ =  payStreams.getFeeInBasisPoints();
        assertEq(basisPoint_, newBasisPoint );
        vm.stopPrank();
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

    function testCollectFee() public setSupportedToken  {
       // note this function is should be done after setVaultForStream function have been sorted out. 
       // get the streamData struct
       vm.startPrank(payStreamer);
       mpyUSD.mint(payStreamer, USDC10k);
       IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
           streamer: payStreamer,
           streamerVault: address(0),
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

       string memory _tag = "HamidStream";
       // console.log(streamData.streamerVault);
       bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);

        // Advance the time by 1 day to make funds collectible
       vm.warp(block.timestamp + 1 days);
       uint expectedCollectedAmount =( streamData.amount * (block.timestamp - streamData.startingTimestamp) / streamData.duration  ) - streamData.totalStreamed;
       uint expectedFee = (expectedCollectedAmount * payStreams.getFeeInBasisPoints()) / 10_000;
       (uint expectedAmountToWitdraw, uint ExpectedFee) = (expectedCollectedAmount- expectedFee, expectedFee );
       (uint256 ActualAmountToWithdraw,uint256 ActualFee ) = payStreams.getAmountToCollectFromStreamAndFeeToPay(actualStreamHash);
       vm.startPrank(payStreamer);
       mpyUSD.approve(address(payStreams), type(uint256).max);
       payStreams.collectFundsFromStream(actualStreamHash);
       vm.stopPrank();


       // now we handle the fee collected by the protocol
       vm.startPrank(payStreamTeamAddress1);
       payStreams.collectFees(streamData.token, ActualFee);
       uint amountOfFeeCollected = mpyUSD.balanceOf(payStreamTeamAddress1);
       console.log("this is the total amount of fee collected", amountOfFeeCollected);
       assertEq(amountOfFeeCollected, ActualFee);
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

    function  testSetVaultForReceiver() public setSupportedToken{
        vm.startPrank(payReceiver);
        makeVaultForReceipient = new MakeVaultforReceipient(address(payReceiver));
        vm.stopPrank();
        vm.startPrank(payStreamer);
        makeVaultForStreamer = new MakeVaultforStreamer(address(payStreamer));
        mpyUSD.mint(payStreamer, USDC10k );
        IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
            streamer: payStreamer,
            streamerVault: address(makeVaultForStreamer),
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
        makeHook = MakeHook(payStreamer);
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
            callBeforeFundsCollected: true,
            callAfterFundsCollected: false,
            callBeforeStreamUpdated: false,
            callAfterStreamUpdated: false,
            callBeforeStreamClosed: false,
            callAfterStreamClosed: false
        });

        string memory _tag = "HamidStream";
        console.log(streamData.streamerVault);
        bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);
        payStreams.setHookConfigForStream(actualStreamHash, hookConfig);

        bool boolCallAfterStreamCreated = payStreams.getHookConfig(payStreamer, actualStreamHash).callBeforeFundsCollected;
        // note that when bool boolCallAfterStreamCreated = payStreams.getHookConfig(payStreamer, actualStreamHash).callAfterStreamCreated; it reverts on evm error. more test to be conducted
        console.log(boolCallAfterStreamCreated);
        assertEq(boolCallAfterStreamCreated, hookConfig.callBeforeFundsCollected);
        vm.stopPrank();
    }
    // function testMockHookafterFundsCollected() public {
    //     // note this test can be done after the remain work are done.
        
    // }

    function testGetAmountToCollectFree() public setSupportedToken {
        vm.startPrank(payStreamer);
        mpyUSD.mint(payStreamer, USDC10k);
        IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
            streamer: payStreamer,
            streamerVault: address(0),
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

        string memory _tag = "HamidStream";
        // console.log(streamData.streamerVault);
        bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);

         // Advance the time by 1 day to make funds collectible
        vm.warp(block.timestamp + 1 days);
        console.log("this is the streamed total Amount",streamData.totalStreamed);
        console.log("this is the currenting time stamp after a day", block.timestamp);
        console.log("this was the timestamp a day before",streamData.startingTimestamp);
        console.log("this the durtion",streamData.duration);
        vm.stopPrank();
        uint expectedCollectedAmount =( streamData.amount * (block.timestamp - streamData.startingTimestamp) / streamData.duration  ) - streamData.totalStreamed;
        uint expectedFee = (expectedCollectedAmount * payStreams.getFeeInBasisPoints()) / 10_000;
        console.log("this is the expected collected fee",expectedFee );
        (uint expectedAmountToWitdraw, uint ExpectedFee) = (expectedCollectedAmount- expectedFee, expectedFee );
        console.log ("this is the expected collected Amount", expectedCollectedAmount);
        (uint256 ActualAmountToWithdraw,uint256 ActualFee ) = payStreams.getAmountToCollectFromStreamAndFeeToPay(actualStreamHash);
        console.log("these are the amountToWithdraw and fee amunt ", ActualAmountToWithdraw,ActualFee);

        assertEq(expectedAmountToWitdraw, ActualAmountToWithdraw);
        assertEq(expectedFee, ActualFee);

    }
    function testCollectFundFromStream() public setSupportedToken {
        vm.startPrank(payStreamer);
        mpyUSD.mint(payStreamer, USDC10k);
        IPayStreams.StreamData memory streamData = IPayStreams.StreamData({
            streamer: payStreamer,
            streamerVault: address(0),
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

        string memory _tag = "HamidStream";
        // console.log(streamData.streamerVault);
        bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);

         // Advance the time by 1 day to make funds collectible
        vm.warp(block.timestamp + 1 days);
        uint expectedCollectedAmount =( streamData.amount * (block.timestamp - streamData.startingTimestamp) / streamData.duration  ) - streamData.totalStreamed;
        uint expectedFee = (expectedCollectedAmount * payStreams.getFeeInBasisPoints()) / 10_000;
        (uint expectedAmountToWitdraw, uint ExpectedFee) = (expectedCollectedAmount- expectedFee, expectedFee );
        (uint256 ActualAmountToWithdraw,uint256 ActualFee ) = payStreams.getAmountToCollectFromStreamAndFeeToPay(actualStreamHash);
        console.log("this is the streamer address",streamData.streamer);
        console.log("this is the pay streamer address", payStreamer);
        console.log("this is the payStream contract address", address(payStreams));
        vm.startPrank(payStreamer);
        mpyUSD.approve(address(payStreams), type(uint256).max);
        payStreams.collectFundsFromStream(actualStreamHash);
        vm.stopPrank();
    }

    function testUpdateStream() public setSupportedToken {
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
        vm.stopPrank();

        vm.startPrank(payStreamer);
        // handle the update stream function
        vm.warp(block.timestamp + 2 days);
        uint newAmount = 1_200;
        uint newStartTimStamp = block.timestamp;
        uint newDuration = 2 weeks;
        bool recurring = true;

        payStreams.updateStream(streamHash,newAmount, newStartTimStamp,newDuration, recurring);
        
        vm.stopPrank();
        IPayStreams.StreamData memory updatedStreamData = payStreams.getStreamData(streamHash);

        // Assert updated values to match set in the updateStream
    assertEq(updatedStreamData.amount, newAmount);
    assertEq(updatedStreamData.startingTimestamp, newStartTimStamp);
    assertEq(updatedStreamData.duration, newDuration);
    assertEq(updatedStreamData.recurring, recurring);
    }
    function testCancelStream() public setSupportedToken{
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
        vm.stopPrank();

        vm.startPrank(payStreamer);
        // handle the cancel stream function
        vm.warp(block.timestamp + 2 days);
        payStreams.cancelStream(streamHash);
        vm.stopPrank();

        IPayStreams.StreamData memory cancelledStreamData = payStreams.getStreamData(streamHash);
        assertEq(cancelledStreamData.amount, 0);

    }
    function testgetStreamHash() public setSupportedToken{
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
        bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);
        vm.stopPrank();
        address expectedStreamer = payStreamer;
        address expectedReceipent = payReceiver;
        address expectedToken = address(mpyUSD);
        string memory expectedSalt = "HamidStream";
        // TEST getSteamHash
        bytes32 actualStremaHash = payStreams.getStreamHash(expectedStreamer, expectedReceipent, expectedToken, expectedSalt);
        bytes32 expectedStreamHash = keccak256(abi.encode(streamData.streamer, streamData.recipient, streamData.token, _tag));
        assertEq(actualStreamHash, expectedStreamHash);
    }

    function testReceiverStreamHash() public setSupportedToken {
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
        bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);
        vm.stopPrank();
        vm.startPrank(payStreamer);
        IPayStreams.StreamData memory streamData2 = IPayStreams.StreamData({
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
        IPayStreams.HookConfig memory hookConfig2 = IPayStreams.HookConfig({
            callAfterStreamCreated:false,
            callBeforeFundsCollected: true,
            callAfterFundsCollected: false,
            callBeforeStreamUpdated: false,
            callAfterStreamUpdated: false,
            callBeforeStreamClosed: false,
            callAfterStreamClosed: false
        });

        string memory _tag2 = "OscarStream";
        bytes32 actualStreamHash2 = payStreams.setStream(streamData2, hookConfig2, _tag2);
        vm.stopPrank();
        // get receiver hash

        bytes32[] memory streamHashes = payStreams.getRecipientStreamHashes(payReceiver);
        // bytes32[] memory streamHashes = payStreams.getStreamerStreamHashes(payReceiver);

        assertEq(streamHashes.length, 2, "Expected two stream hashes for the receiver.");

        assertEq(actualStreamHash, streamHashes[0]);
        assertEq(actualStreamHash2, streamHashes[1]);
    }

    

    function testStreamerStreamHash() public setSupportedToken {
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
        bytes32 actualStreamHash = payStreams.setStream(streamData, hookConfig, _tag);
        vm.stopPrank();
        vm.startPrank(payStreamer);
        IPayStreams.StreamData memory streamData2 = IPayStreams.StreamData({
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
        IPayStreams.HookConfig memory hookConfig2 = IPayStreams.HookConfig({
            callAfterStreamCreated:false,
            callBeforeFundsCollected: true,
            callAfterFundsCollected: false,
            callBeforeStreamUpdated: false,
            callAfterStreamUpdated: false,
            callBeforeStreamClosed: false,
            callAfterStreamClosed: false
        });

        string memory _tag2 = "OscarStream";
        bytes32 actualStreamHash2 = payStreams.setStream(streamData2, hookConfig2, _tag2);
        vm.stopPrank();
        // get receiver hash

        // bytes32[] memory streamHashes = payStreams.getRecipientStreamHashes(payReceiver);
        bytes32[] memory streamHashes = payStreams.getStreamerStreamHashes(payStreamer);

        assertEq(streamHashes.length, 2, "Expected two stream hashes for the receiver.");

        assertEq(actualStreamHash, streamHashes[0]);
        assertEq(actualStreamHash2, streamHashes[1]);
    }
}
