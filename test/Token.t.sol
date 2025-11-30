// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Token.sol";

contract TokenTest is Test {
    Token public token;
    
    address public account0;
    address public account1;
    address public account2;
    address public account3;
    address public account5;
    address public account9;
    
    function setUp() public {
        token = new Token();
        
        // Create proper addresses that can receive ETH
        account0 = makeAddr("account0");
        account1 = makeAddr("account1");
        account2 = makeAddr("account2");
        account3 = makeAddr("account3");
        account5 = makeAddr("account5");
        account9 = makeAddr("account9");
        
        // Fund test accounts with ETH
        vm.deal(account0, 1000 ether);
        vm.deal(account1, 1000 ether);
        vm.deal(account2, 1000 ether);
        vm.deal(account3, 1000 ether);
        vm.deal(account5, 1000 ether);
        vm.deal(account9, 1000 ether);
    }
    
    function assertHolderList(address[] memory expectedHolders) internal view {
        uint256 numHolders = token.getNumTokenHolders();
        assertEq(numHolders, expectedHolders.length, "Number of holders mismatch");
        
        // Get actual holders
        address[] memory actualHolders = new address[](numHolders);
        for (uint256 i = 0; i < numHolders; i++) {
            actualHolders[i] = token.getTokenHolder(i + 1); // 1-indexed
        }
        
        // Sort both arrays for comparison
        _sortAddresses(actualHolders);
        _sortAddresses(expectedHolders);
        
        // Compare
        for (uint256 i = 0; i < numHolders; i++) {
            assertEq(actualHolders[i], expectedHolders[i], "Holder mismatch");
        }
    }
    
    function _sortAddresses(address[] memory arr) internal pure {
        uint256 l = arr.length;
        for (uint256 i = 0; i < l; i++) {
            for (uint256 j = i + 1; j < l; j++) {
                if (arr[i] > arr[j]) {
                    address temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                }
            }
        }
    }
    
    function test_HasDefaultValues() public view{
        assertEq(token.name(), "Test token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }
    
    function test_CanBeMinted() public {
        // Should fail with no value
        vm.prank(account0);
        vm.expectRevert("Must send ether to mint");
        token.mint();
        
        // Mint 23
        vm.prank(account0);
        token.mint{value: 23}();
        assertEq(token.balanceOf(account0), 23);
        assertEq(token.totalSupply(), 23);
        
        // Mint 50 more
        vm.prank(account0);
        token.mint{value: 50}();
        assertEq(token.balanceOf(account0), 73);
        assertEq(token.totalSupply(), 73);
        assertEq(address(token).balance, 73);
        
        // Mint from account1
        vm.prank(account1);
        token.mint{value: 50}();
        assertEq(token.balanceOf(account0), 73);
        assertEq(token.balanceOf(account1), 50);
        assertEq(token.totalSupply(), 123);
        assertEq(address(token).balance, 123);
    }
    
    function test_CanBeBurnt() public {
        vm.prank(account0);
        token.mint{value: 23}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        assertEq(address(token).balance, 73);
        
        uint256 preBal = account9.balance;
        
        vm.prank(account0);
        token.burn(payable(account9));
        
        assertEq(address(token).balance, 50);
        
        uint256 postBal = account9.balance;
        assertEq(postBal - preBal, 23);
    }
    
    function test_CanBeTransferredDirectly() public {
        vm.prank(account0);
        token.mint{value: 50}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        // Transfer from account1 to account2
        vm.prank(account1);
        token.transfer(account2, 1);
        
        assertEq(token.balanceOf(account1), 49);
        assertEq(token.balanceOf(account2), 1);
        assertEq(token.totalSupply(), 100);
        
        // Should fail - insufficient balance
        vm.prank(account2);
        vm.expectRevert("Insufficient balance");
        token.transfer(account1, 2);
    }
    
    function test_CanBeTransferredIndirectly() public {
        vm.prank(account0);
        token.mint{value: 50}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        // Approve account1 for 5
        vm.prank(account0);
        token.approve(account1, 5);
        assertEq(token.allowance(account0, account1), 5);
        
        // Update approval to 10
        vm.prank(account0);
        token.approve(account1, 10);
        assertEq(token.allowance(account0, account1), 10);
        
        // Should fail - amount exceeds allowance
        vm.prank(account1);
        vm.expectRevert("Insufficient allowance");
        token.transferFrom(account0, account2, 11);
        
        // Transfer 9
        vm.prank(account1);
        token.transferFrom(account0, account2, 9);
        
        assertEq(token.balanceOf(account0), 41);
        assertEq(token.balanceOf(account1), 50);
        assertEq(token.balanceOf(account2), 9);
        assertEq(token.allowance(account0, account1), 1);
        
        // Should fail - amount exceeds remaining allowance
        vm.prank(account1);
        vm.expectRevert("Insufficient allowance");
        token.transferFrom(account0, account1, 2);
        
        // Transfer remaining allowance
        vm.prank(account1);
        token.transferFrom(account0, account1, 1);
        
        assertEq(token.balanceOf(account0), 40);
        assertEq(token.balanceOf(account1), 51);
        assertEq(token.balanceOf(account2), 9);
        assertEq(token.allowance(account0, account1), 0);
    }
    
    function test_DisallowsEmptyDividend() public {
        vm.prank(account0);
        token.mint{value: 50}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        vm.prank(account5);
        vm.expectRevert("Must send ether for dividend");
        token.recordDividend();
    }
    
    function test_KeepsTrackOfHoldersWhenMintingAndBurning() public {
        vm.prank(account0);
        token.mint{value: 50}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        address[] memory holders1 = new address[](2);
        holders1[0] = account0;
        holders1[1] = account1;
        assertHolderList(holders1);
        
        // Mint from account2
        vm.prank(account2);
        token.mint{value: 100}();
        
        // Burn from account0
        vm.prank(account0);
        token.burn(payable(account9));
        
        assertEq(token.balanceOf(account0), 0);
        assertEq(token.balanceOf(account1), 50);
        assertEq(token.balanceOf(account2), 100);
        
        address[] memory holders2 = new address[](2);
        holders2[0] = account1;
        holders2[1] = account2;
        assertHolderList(holders2);
        
        // Record dividend
        vm.prank(account5);
        token.recordDividend{value: 1500}();
        
        assertEq(token.getWithdrawableDividend(account0), 0);
        assertEq(token.getWithdrawableDividend(account1), 500);
        assertEq(token.getWithdrawableDividend(account2), 1000);
        
        assertHolderList(holders2);
    }
    
    function test_KeepsTrackOfHoldersWhenTransferring() public {
        vm.prank(account0);
        token.mint{value: 50}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        // Transfer to account2
        vm.prank(account0);
        token.transfer(account2, 25);
        
        // Transfer 0 to account3
        vm.prank(account0);
        token.transfer(account3, 0);
        
        // Approve and transferFrom
        vm.prank(account1);
        token.approve(account0, 50);
        
        vm.prank(account0);
        token.transferFrom(account1, account2, 50);
        
        assertEq(token.balanceOf(account0), 25);
        assertEq(token.balanceOf(account1), 0);
        assertEq(token.balanceOf(account2), 75);
        assertEq(token.balanceOf(account3), 0);
        
        address[] memory holders = new address[](2);
        holders[0] = account0;
        holders[1] = account2;
        assertHolderList(holders);
        
        // Record dividend
        vm.prank(account5);
        token.recordDividend{value: 1000}();
        
        assertEq(token.getWithdrawableDividend(account0), 250);
        assertEq(token.getWithdrawableDividend(account1), 0);
        assertEq(token.getWithdrawableDividend(account2), 750);
        assertEq(token.getWithdrawableDividend(account3), 0);
    }
    
    function test_CompoundsThePayouts() public {
        vm.prank(account0);
        token.mint{value: 50}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        // Transfer to account2
        vm.prank(account0);
        token.transfer(account2, 25);
        
        assertEq(token.balanceOf(account0), 25);
        assertEq(token.balanceOf(account1), 50);
        assertEq(token.balanceOf(account2), 25);
        
        // Record first dividend
        vm.prank(account5);
        token.recordDividend{value: 1000}();
        
        assertEq(token.getWithdrawableDividend(account0), 250);
        assertEq(token.getWithdrawableDividend(account1), 500);
        assertEq(token.getWithdrawableDividend(account2), 250);
        
        // Do some transfers to update proportional holdings
        vm.prank(account1);
        token.transfer(account2, 25);
        
        vm.prank(account1);
        token.mint{value: 75}();
        
        vm.prank(account0);
        token.burn(payable(account0));
        
        assertEq(token.balanceOf(account0), 0);
        assertEq(token.balanceOf(account1), 100);
        assertEq(token.balanceOf(account2), 50);
        assertEq(token.totalSupply(), 150);
        
        address[] memory holders = new address[](2);
        holders[0] = account1;
        holders[1] = account2;
        assertHolderList(holders);
        
        // Record second dividend
        vm.prank(account5);
        token.recordDividend{value: 90}();
        
        // Check that new payouts are in accordance with new holding proportions
        assertEq(token.getWithdrawableDividend(account0), 250 + 0);
        assertEq(token.getWithdrawableDividend(account1), 500 + 60);
        assertEq(token.getWithdrawableDividend(account2), 250 + 30);
    }
    
    function test_AllowsWithdrawalsInBetweenPayouts() public {
        vm.prank(account0);
        token.mint{value: 50}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        vm.prank(account0);
        token.transfer(account2, 25);
        
        assertEq(token.balanceOf(account0), 25);
        assertEq(token.balanceOf(account1), 50);
        assertEq(token.balanceOf(account2), 25);
        
        address[] memory holders = new address[](3);
        holders[0] = account0;
        holders[1] = account1;
        holders[2] = account2;
        assertHolderList(holders);
        
        // Record dividend
        vm.prank(account5);
        token.recordDividend{value: 1000}();
        
        assertEq(token.getWithdrawableDividend(account0), 250);
        assertEq(token.getWithdrawableDividend(account1), 500);
        assertEq(token.getWithdrawableDividend(account2), 250);
        
        // Withdraw from account1
        uint256 preBal = account9.balance;
        vm.prank(account1);
        token.withdrawDividend(payable(account9));
        uint256 postBal = account9.balance;
        
        assertEq(postBal - preBal, 500);
        
        // Check that withdrawable balance has been reset for account1
        assertEq(token.getWithdrawableDividend(account0), 250);
        assertEq(token.getWithdrawableDividend(account1), 0);
        assertEq(token.getWithdrawableDividend(account2), 250);
    }
    
    function test_AllowsWithdrawalsEvenAfterHolderRelinquishesTokens() public {
        vm.prank(account0);
        token.mint{value: 50}();
        
        vm.prank(account1);
        token.mint{value: 50}();
        
        vm.prank(account0);
        token.transfer(account2, 25);
        
        assertEq(token.balanceOf(account0), 25);
        assertEq(token.balanceOf(account1), 50);
        assertEq(token.balanceOf(account2), 25);
        
        address[] memory holders1 = new address[](3);
        holders1[0] = account0;
        holders1[1] = account1;
        holders1[2] = account2;
        assertHolderList(holders1);
        
        // Record dividend
        vm.prank(account5);
        token.recordDividend{value: 1000}();
        
        assertEq(token.getWithdrawableDividend(account0), 250);
        assertEq(token.getWithdrawableDividend(account1), 500);
        assertEq(token.getWithdrawableDividend(account2), 250);
        
        uint256 preBal = account9.balance;
        
        // Burn tokens from account1
        vm.prank(account1);
        token.burn(payable(account9));
        
        address[] memory holders2 = new address[](2);
        holders2[0] = account0;
        holders2[1] = account2;
        assertHolderList(holders2);
        
        assertEq(token.getWithdrawableDividend(account0), 250);
        assertEq(token.getWithdrawableDividend(account1), 500);
        assertEq(token.getWithdrawableDividend(account2), 250);
        
        // Try withdrawing
        vm.prank(account1);
        token.withdrawDividend(payable(account9));
        
        // Check dest balances
        uint256 postBal = account9.balance;
        assertEq(postBal - preBal, 50 + 500);
        
        assertEq(token.getWithdrawableDividend(account0), 250);
        assertEq(token.getWithdrawableDividend(account1), 0);
        assertEq(token.getWithdrawableDividend(account2), 250);
        
        // Record new dividend
        vm.prank(account5);
        token.recordDividend{value: 80}();
        
        // This time account1 doesn't get any payout because they no longer hold tokens
        assertEq(token.getWithdrawableDividend(account0), 250 + 40);
        assertEq(token.getWithdrawableDividend(account1), 0);
        assertEq(token.getWithdrawableDividend(account2), 250 + 40);
    }
}