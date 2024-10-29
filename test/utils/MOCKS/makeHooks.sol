// SDPX-License-Identifier: MIT

pragma solidity 0.8.24;

import {MockpyUSD} from "../MOCKS/MockpyUSD.sol";
import {initializeTokenAndActors} from "../Helpers/initializeTokenAndActors.sol";
import {IHooks} from "../../../src/interfaces/IHooks.sol";
import {MakeVaultforStreamer} from "../MOCKS/makeVault.sol";

contract MakeHook is initializeTokenAndActors{

    
    address public onlyStreamer;
    address public hookReceiver = payReceiver;


    IHooks public iHooks;


    error makeHook_NotTheStreamerError();
    error makeHook_notMonadexReceiver();

    constructor(address _onlyStreamer) {
        onlyStreamer = _onlyStreamer;
    }
    function makeStreamerHook(bytes32 _streamHash, address worker) public  {
        if (msg.sender != onlyStreamer){
            revert makeHook_NotTheStreamerError();
        }

        iHooks.afterStreamCreated(_streamHash);
        if (worker != hookReceiver) {
            revert makeHook_notMonadexReceiver();
        }
    }

    function mockHookafterFundsCollected(bytes32 _streamHash, uint amount, uint fee) public {
        //weekly deposit to subcribe for netFlix address
        if (msg.sender != hookReceiver){
            revert makeHook_NotTheStreamerError();
        }
        iHooks.afterFundsCollected(_streamHash, amount, fee);
        uint startingTimeStamp = block.timestamp;
        uint duration = 1 weeks;
        if (block.timestamp > startingTimeStamp + duration) {
            mpyUSD.transferFrom(payReceiver, payNetflix, amount );
        }
    }

    function setPoolReceiver(address receiver) public {
        hookReceiver = receiver;
    }
}