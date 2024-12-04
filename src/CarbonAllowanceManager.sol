// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

error CarbonManager__NotOwner(address owner, address operator);
error CarbonManager__AllowanceNotEnough(address operator, uint256 balance, uint256 needed);    // 碳排放额不够
error ERC20__TransferFailed(address from, address to, uint256 amount);

contract CarbonAllowanceManager {
    mapping(address => uint256) public addressToAllowances;
    mapping(address => uint256) public frozenAllowances;
    address public owner;

    constructor() {
        owner = msg.sender;
    }
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert CarbonManager__NotOwner(owner, msg.sender);
        }
        _;
    }

    function updateOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function issueAllowance(address _user, uint256 _allowance) public onlyOwner {
        addressToAllowances[_user] += _allowance;
    }

    function freezeAllowance(address _user, uint256 _freezedAmount) public onlyOwner {
        addressToAllowances[_user] -= _freezedAmount;
        frozenAllowances[_user] += _freezedAmount;
    }

    function unfreezeAllowance(address _user, uint256 _unfreezedAmount) public onlyOwner {
        addressToAllowances[_user] += _unfreezedAmount;
        frozenAllowances[_user] -= _unfreezedAmount;
    }

    function destoryAllowance(address _user, uint256 _destoryAmount) public onlyOwner {
        addressToAllowances[_user] -= _destoryAmount;
    }

    function destoryAllAllowance(address _user) public onlyOwner {
        addressToAllowances[_user] = 0;
        frozenAllowances[_user] = 0;
    }
}
