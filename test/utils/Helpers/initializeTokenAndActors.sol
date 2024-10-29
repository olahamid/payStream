// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;
    // ---------------------------
    //      ACTOR INITIALISER
    // ---------------------------
import {Test} from "../../../lib/forge-std/src/Test.sol";
import {console} from "../../../lib/forge-std/src/console.sol";

import {MockpyUSD} from "../MOCKS/MockpyUSD.sol";
import {MockToken} from "../MOCKS/MockToken.sol";
contract initializeTokenAndActors is Test {

    uint256 public constant USDC1 = 1e6; // 1 e 6 stable Coin
    uint256 public constant USDC10k = 1e10; // 10k stable Coin
    uint256 public constant USDC100k = 1e11; // 100k stable Coin

    MockToken mpyUSD = new MockToken("PayPal Mock USD", "mockpyUSD", 6);
    MockToken wUSDT = new MockToken ("wUSDT", "wUSDT", 6);
    MockToken wETH =  new MockToken ("wETH", "wETH", 18);

    MockpyUSD pyUSD = new MockpyUSD(USDC100k);

    // ---------------------------
    //      ADMIN ACTORS
    // ---------------------------
    address payStreamTeamAddress1 = makeAddr("protocolpayStreamTeamAddress1");
    address payStreamTeamAddress2 = makeAddr("protocolpayStreamTeamAddress2");

    // ---------------------------
    //      STREAMER ACTORS
    // ---------------------------
    address payStreamer = makeAddr("makePayStreamer");
    address payStreamer2 = makeAddr("makePayStreamer2");
    address payStreamer3 = makeAddr("makePayStreamer3");

    // ---------------------------
    //      RECEIVER ACTORS
    // ---------------------------
    address payReceiver = makeAddr("makeReceiver");
    address payReceiver2 = makeAddr("makeReceiver2");
    address payReceiver3 = makeAddr("makeReceiver3");
    address payReceiver4 =  makeAddr("makeReceiver4");
    address payReceiver5 = makeAddr("makeReceiver5"); 

    address payNetflix = makeAddr("netnetflixHook");
}