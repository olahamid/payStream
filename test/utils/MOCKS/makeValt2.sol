//SPDX-License-Identifier: MIT 

pragma solidity 0.8.24;

import {MockpyUSD} from "../MOCKS/MockpyUSD.sol";
import {initializeTokenAndActors} from "../Helpers/initializeTokenAndActors.sol";
import {BaseVault} from "../../../src/utils/BaseVaults.sol";
contract  MakeVaultforReceipient is initializeTokenAndActors, BaseVault{

    address public onlyReciepeint;

    error makeVault_NotTheReceipentError();

    constructor (address _onlyReceipient) {
        onlyReciepeint = _onlyReceipient;
    }
    function receiverWithdrawFromVault(uint amount) public {
        if (msg.sender != onlyReciepeint) {
            revert makeVault_NotTheReceipentError();
        }
        mpyUSD.transferFrom(address(this), msg.sender, amount);
               
    }
}