// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;


import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockpyUSD {
    string public name = "MOCK PAY PAL USD";
    string public symbol = "pyUSD";
    uint8 public decimal = 6;

    uint public totalSupply;

    mapping(address => uint256) balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event e_Deposit(address indexed user, uint256 amount);
    event e_Withdrawal(address indexed user, uint256 amount);


    constructor (uint _totalSupply) {
        totalSupply = _totalSupply;
    }


    function withdraw(uint256 amount) public {
        require(balanceOf[msg.sender] > amount);

        balanceOf[msg.sender] -= amount;
        (bool success,) = payable(msg.sender).call{ value: amount }("");
        require(success, "transfer failed on function withdraw");
        // payable(msg.sender).transfer(amount);
        emit e_Withdrawal(msg.sender, amount);
    }

    function getTotalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    function approve(address user, uint256 amount) public returns (bool) {
        allowance[msg.sender][user] = amount;
        return true;
    }

    function transfer(address addrTo, uint256 amount) public returns (bool) {
        return transferFrom(msg.sender, addrTo, amount);
    }

    function transferFrom(address addrFrom, address addrTo, uint256 amount) public returns (bool) {
        if (addrFrom != msg.sender && allowance[addrFrom][msg.sender] != type(uint256).max) {
            require(allowance[addrFrom][msg.sender] >= amount);
            allowance[addrFrom][msg.sender] -= amount;
        }

        balanceOf[addrFrom] -= amount;
        balanceOf[addrTo] += amount;

        return true;
    }
}