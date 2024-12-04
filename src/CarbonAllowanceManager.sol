// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICarbonPortal {
    function isMember(address attester) external view returns(bool);
    function uploadAttest(address attester) external;
}

contract CarbonAllowanceManager {
    error CarbonManager__NotOwner(address owner, address operator);
    error CarbonManager__AllowanceNotEnough(address operator, uint256 balance, uint256 needed);    // 碳排放额不够
    error ERC20__TransferFailed(address from, address to, uint256 amount);
    error CarbonManager__InvalidOwner();
    error CarbonManager__NotMember(address operator);

    mapping(address => uint256) public addressToAllowances;
    mapping(address => uint256) public frozenAllowances;
    address public owner;

    ICarbonPortal public carbonPortal;

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
        if (_newOwner == address(0)) revert CarbonManager__InvalidOwner();
        owner = _newOwner;
    }

    function updateCarbonPortal(address _carbonPortal) public onlyOwner {
        carbonPortal = ICarbonPortal(_carbonPortal);
    }

    function issueAllowance(address _user, uint256 _allowance) public onlyOwner {
        if(!isMember(_user)) carbonPortal.uploadAttest(_user);  // verax
        addressToAllowances[_user] += _allowance;
    }

    function freezeAllowance(address _user, uint256 _freezedAmount) public onlyOwner {
        if(_freezedAmount > addressToAllowances[_user]) revert CarbonManager__AllowanceNotEnough(_user, addressToAllowances[_user], _freezedAmount);
        addressToAllowances[_user] -= _freezedAmount;
        frozenAllowances[_user] += _freezedAmount;
    }

    function unfreezeAllowance(address _user, uint256 _unfreezedAmount) public onlyOwner {
        if(_unfreezedAmount > frozenAllowances[_user]) revert CarbonManager__AllowanceNotEnough(_user, frozenAllowances[_user], _unfreezedAmount);
        addressToAllowances[_user] += _unfreezedAmount;
        frozenAllowances[_user] -= _unfreezedAmount;
    }

    function destoryAllowance(address _user, uint256 _destoryAmount) public onlyOwner {
        if(_destoryAmount > addressToAllowances[_user]) revert CarbonManager__AllowanceNotEnough(_user, addressToAllowances[_user], _destoryAmount);
        addressToAllowances[_user] -= _destoryAmount;
    }

    function destoryAllAllowance(address _user) public onlyOwner {
        addressToAllowances[_user] = 0;
        frozenAllowances[_user] = 0;
    }

    function isMember(address _user) public returns(bool) {
        return carbonPortal.isMember(_user);
    }
}
