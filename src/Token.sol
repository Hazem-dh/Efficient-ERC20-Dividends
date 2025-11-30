// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";

contract Token is IERC20, IMintableToken, IDividends {

  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  
  mapping (address => uint256) public balanceOf;
  mapping (address => mapping (address => uint256)) private _allowances;
  
  // Reentrancy guard
  uint256 private constant _NOT_ENTERED = 1;
  uint256 private constant _ENTERED = 2;
  uint256 private _status;
  
  // Scalable dividend tracking
  uint256 private constant POINTS_MULTIPLIER = 1e18;
  uint256 private totalDividendPoints;
  mapping (address => uint256) private lastDividendPoints;
  mapping (address => uint256) private savedDividends;
  
  // Holder tracking (required by IDividends interface)
  address[] private holders;
  mapping (address => bool) private isHolder;
  mapping (address => uint256) private holderIndex;
  
  constructor() {
    _status = _NOT_ENTERED;
  }
  
  modifier nonReentrant() {
    require(_status != _ENTERED, "Reentrant call");
    _status = _ENTERED;
    _;
    _status = _NOT_ENTERED;
  }
  
  // IERC20
  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }
  
  function transfer(address to, uint256 value) external override returns (bool) {
    require(balanceOf[msg.sender] >= value, "Insufficient balance");
    
    _transfer(msg.sender, to, value);
    
    return true;
  }
  
  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    return true;
  }
  
  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(_allowances[from][msg.sender] >= value, "Insufficient allowance");
    require(balanceOf[from] >= value, "Insufficient balance");
    
    _allowances[from][msg.sender] = _allowances[from][msg.sender] - value;
    _transfer(from, to, value);
    
    return true;
  }
  
  // Internal transfer function with dividend tracking
  function _transfer(address from, address to, uint256 value) internal {
    require(from != address(0), "Transfer from zero address");
    require(to != address(0), "Transfer to zero address");
    require(from != to, "Cannot transfer to yourself");
    
    // Save earned dividends before balance changes
    _saveDividends(from);
    _saveDividends(to);
    
    balanceOf[from] = balanceOf[from] - value;
    balanceOf[to] = balanceOf[to] + value;
    
    // Update holder list
    if (balanceOf[from] == 0 && isHolder[from]) {
      _removeHolder(from);
    }
    
    if (!isHolder[to] && balanceOf[to] > 0) {
      _addHolder(to);
    }
  }
  
  // IMintableToken
  function mint() external payable override {
    require(msg.value > 0, "Must send ether to mint");
    
    _saveDividends(msg.sender);
    
    balanceOf[msg.sender] = balanceOf[msg.sender] + msg.value;
    totalSupply = totalSupply + msg.value;
    
    if (!isHolder[msg.sender]) {
      _addHolder(msg.sender);
    }
  }
  
  function burn(address payable dest) external override nonReentrant {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "No balance to burn");
    require(dest != address(0), "Cannot burn to zero address");
    
    _saveDividends(msg.sender);
    
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply - amount;
    
    if (isHolder[msg.sender]) {
      _removeHolder(msg.sender);
    }
    
    (bool success, ) = dest.call{value: amount}("");
    require(success, "Transfer failed");
  }
  
  // IDividends
  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }
  
  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index > 0 && index <= holders.length, "Invalid index");
    return holders[index - 1];
  }
  
  function recordDividend() external payable override {
    require(msg.value > 0, "Must send ether for dividend");
    
    uint256 supply = totalSupply;
    require(supply > 0, "No tokens in circulation");
    
    // O(1) dividend distribution using points system
    totalDividendPoints = totalDividendPoints + (msg.value * POINTS_MULTIPLIER / supply);
  }
  
  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    uint256 newDividends = _calculateNewDividends(payee);
    return savedDividends[payee] + newDividends;
  }
  
  function withdrawDividend(address payable dest) external override nonReentrant {
    require(dest != address(0), "Cannot withdraw to zero address");
    
    _saveDividends(msg.sender);
    
    uint256 amount = savedDividends[msg.sender];
    require(amount > 0, "No dividend to withdraw");
    
    savedDividends[msg.sender] = 0;
    
    (bool success, ) = dest.call{value: amount}("");
    require(success, "Transfer failed");
  }
  
  // Helper functions for scalable dividend tracking
  // This saves dividends earned with CURRENT balance before balance changes
  // After this, future dividends will be calculated with the NEW balance
  function _saveDividends(address account) internal {
    uint256 newDividends = _calculateNewDividends(account);
    if (newDividends > 0) {
      savedDividends[account] = savedDividends[account] + newDividends;
    }
    // Update checkpoint - future dividends calculated from here with new balance
    lastDividendPoints[account] = totalDividendPoints;
  }
  
  // Calculate dividends earned since last checkpoint using CURRENT balance
  function _calculateNewDividends(address account) internal view returns (uint256) {
    uint256 pointsDiff = totalDividendPoints - lastDividendPoints[account];
    return balanceOf[account] * pointsDiff / POINTS_MULTIPLIER;
  }
  
  // Helper functions for holder tracking
  function _addHolder(address holder) internal {
    holderIndex[holder] = holders.length;
    holders.push(holder);
    isHolder[holder] = true;
  }
  
  function _removeHolder(address holder) internal {
    isHolder[holder] = false;
    
    uint256 index = holderIndex[holder];
    uint256 lastIndex = holders.length - 1;
    
    if (index != lastIndex) {
      address lastHolder = holders[lastIndex];
      holders[index] = lastHolder;
      holderIndex[lastHolder] = index;
    }
    
    holders.pop();
    delete holderIndex[holder];
  }
  
  // Fallback to receive ether
  receive() external payable {}
}