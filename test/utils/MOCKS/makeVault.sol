//SDPX-License-Identifier: MIT

pragma solidity 0.8.24;
import {MockpyUSD} from "../MOCKS/MockpyUSD.sol";
import {initializeTokenAndActors} from "../Helpers/initializeTokenAndActors.sol";
import {BaseVault} from "../../../src/utils/BaseVaults.sol";
contract MakeVaultforStreamer is initializeTokenAndActors, BaseVault{

    address public onlyStreamer;

    error makeVault_NotTheStreamerError();
    constructor (address _onlyStreamer ) {
        onlyStreamer = _onlyStreamer;
    }

    function addFundsToVault(uint amountToFund) public {
        if (msg.sender != onlyStreamer) {
            revert makeVault_NotTheStreamerError();
        }
               
        mpyUSD.mint(payStreamer, amountToFund);
        mpyUSD.transferFrom(payStreamer, address(this), amountToFund);
    }

}

