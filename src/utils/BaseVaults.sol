// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IHooks } from "../interfaces/IHooks.sol";

abstract contract BaseVault is Ownable, IHooks {
    constructor() Ownable(msg.sender) { }

    function afterStreamCreated(bytes32 _streamHash) external virtual { }

    function beforeFundsCollected(bytes32 _streamHash, uint256 _amount, uint256 _feeAmount) external virtual { }

    function afterFundsCollected(bytes32 _streamHash, uint256 _amount, uint256 _feeAmount) external virtual { }

    function beforeStreamUpdated(bytes32 _streamHash) external virtual { }

    function afterStreamUpdated(bytes32 _streamHash) external virtual { }

    function beforeStreamClosed(bytes32 _streamHash) external virtual { }

    function afterStreamClosed(bytes32 _streamHash) external virtual { }
}