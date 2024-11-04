// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

error CarbonTrader__NotOwner();
error CarbonTrader__TransferFailed();

contract CarbonAllowanceManager {
    mapping(address => uint256) internal s_addressToAllowances;
    mapping(address => uint256) internal s_frozenAllowances;
    address private immutable i_owner;
    constructor() {
        i_owner = msg.sender;
    }
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert CarbonTrader__NotOwner();
        }
        _;
    }

    function getAllownance(address user) public view returns (uint256) {
        return s_addressToAllowances[user];
    }

    function issueAllowance(address user, uint256 allowance) public onlyOwner {
        s_addressToAllowances[user] += allowance;
    }

    function freezeAllowance(
        address user,
        uint256 freezedAmount
    ) public onlyOwner {
        s_addressToAllowances[user] -= freezedAmount;
        s_frozenAllowances[user] += freezedAmount;
    }

    function getFrozenAllowance(address user) public view returns (uint256) {
        return s_frozenAllowances[user];
    }

    function unfreezeAllowance(
        address user,
        uint256 unfreezedAmount
    ) public onlyOwner {
        s_addressToAllowances[user] += unfreezedAmount;
        s_frozenAllowances[user] -= unfreezedAmount;
    }

    function destoryAllowance(
        address user,
        uint256 destoryAmount
    ) public onlyOwner {
        s_addressToAllowances[user] -= destoryAmount;
    }

    function destoryAllAllowance(address user) public onlyOwner {
        s_addressToAllowances[user] = 0;
        s_frozenAllowances[user] = 0;
    }
}
