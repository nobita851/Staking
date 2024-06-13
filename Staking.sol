// SPDX-License-Identifier: unlicensed

pragma solidity 0.8.19;

interface IERC20 {
    function mint(address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IStaking {
    ///@notice Deposit the amount of staking token to the pool
    function deposit(uint256 amount) external;

    ///@notice Withdraw the staked(deposited) amount of tokens for the caller
    function withdraw() external;

    /// @notice Claim the accumulated rewards for the caller
    function claim() external;
}

contract Staking is IStaking {
    
    struct User {
        uint256 stakedAmount;
        uint256 lastActiveBlock;
        uint256 lastActiveInterest;
        uint256 accruedInterest;
    }

    IERC20 public TRADE;

    uint256 public totalDeposit;
    uint256 public lastActiveBlock;
    uint256 public immutable interestPerBlock;
    uint256 public currentInterestRatePerDeposit;
    mapping(address user => User _user) public UsersInfo;

    constructor(address _TRADE, uint256 _interestPerBlock) payable {
        TRADE = IERC20(_TRADE);
        interestPerBlock = _interestPerBlock;
        lastActiveBlock = block.number;
    }

    function deposit(uint256 amount) external {
        User storage _user = UsersInfo[msg.sender];
        TRADE.transferFrom(msg.sender, address(this), amount);
        _user.accruedInterest += _calculateInterest(msg.sender); 
        _user.stakedAmount += amount;
        _user.lastActiveBlock = block.number;
        _user.lastActiveInterest = _updateInterestRate();
        totalDeposit += amount;
    }

    function withdraw() external {
        User storage _user = UsersInfo[msg.sender];
        _user.accruedInterest += _calculateInterest(msg.sender);
        uint256 amount = _user.stakedAmount;
        _user.stakedAmount = 0;
        _user.lastActiveBlock = block.number;
        _user.lastActiveInterest = _updateInterestRate();
        totalDeposit -= amount;
        TRADE.transfer(msg.sender, amount);
    }

    function claim() external {
        User storage _user = UsersInfo[msg.sender];
        uint256 interestAmount = _user.accruedInterest + _calculateInterest(msg.sender);
        TRADE.mint(msg.sender, interestAmount);
        _user.accruedInterest = 0;
        _user.lastActiveBlock = block.number;
        _user.lastActiveInterest = currentInterestRatePerDeposit;
    }

    function accruedInterest(address user) external view returns (uint256 _accruedInterest) {
        User memory _user = UsersInfo[user];
        _accruedInterest = _user.accruedInterest + _calculateInterest(user);
    }

    function _calculateInterest(address user) internal view returns (uint256 pendingInterest) {
        User memory _user = UsersInfo[user];
        if (totalDeposit > 0)
            pendingInterest = ((block.number - lastActiveBlock) * interestPerBlock * _user.stakedAmount) / totalDeposit;
        if (lastActiveBlock > _user.lastActiveBlock)
            pendingInterest += ((currentInterestRatePerDeposit - _user.lastActiveInterest) * _user.stakedAmount) / 1e18;
    }

    function _updateInterestRate() internal returns (uint256 _currentInterestRatePerDeposit) {        
        _currentInterestRatePerDeposit = currentInterestRatePerDeposit;
        if (totalDeposit > 0)
            _currentInterestRatePerDeposit += ((block.number - lastActiveBlock) * interestPerBlock * 1e18) / totalDeposit;
        currentInterestRatePerDeposit = _currentInterestRatePerDeposit;
        lastActiveBlock = block.number;
    }
}
