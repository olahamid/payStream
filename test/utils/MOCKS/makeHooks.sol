// SDPX-License-Identifier: MIT

pragma solidity 0.8.24;

import {MockpyUSD} from "../MOCKS/MockpyUSD.sol";
import {initializeTokenAndActors} from "../Helpers/initializeTokenAndActors.sol";
import {IHooks} from "../../../src/interfaces/IHooks.sol";

contract makeHookForStreamer is initializeTokenAndActors{

    
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
}