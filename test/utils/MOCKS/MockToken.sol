// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// ---------------------------
//      ERC20 MOCK CONTRACT
// ---------------------------

import {ERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {

    // ---------------------------
    //       STATE VARIABLE
    // ---------------------------
    /// @dev dec could be a 2, 8, 18
    uint8 dec;

    // ---------------------------
    //      CONSTRUCTOR
    // ---------------------------
    /**
     * 
     * @param _name name of the token
     * @param _symbol symbol of the token
     * @param _dec dec of the token
     */
    constructor (string memory _name, string memory _symbol, uint8 _dec) ERC20(_name, _symbol) {
        dec = _dec;
    }

    // ---------------------------
    //      Function
    // ---------------------------

    function mint(address AddrTo, uint256 amount) public {
        _mint(AddrTo, amount);
    }

    function decimals() public view override returns(uint8){
        return dec;
    }
    
}
