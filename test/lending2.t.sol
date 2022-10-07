// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lending.sol";
import "../src/DreamOracle.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20
{
    constructor() ERC20("USDC", "us")
    {

    }

    function mint(address user, uint256 amount) external
    {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external
    {
        _burn(user, amount);
    }
}

contract Lending_test is Test 
{

    USDC public usdc;
    MyLend public lending;
    DreamOracle public dreamoracle;

    address public alice;
    address public bob;
    function setUp() public 
    {
        usdc = new USDC();
        dreamoracle = new DreamOracle();
        lending = new MyLend(address(usdc), address(dreamoracle));

        dreamoracle.setPrice(address(usdc), 1 ether);
        dreamoracle.setPrice(address(0), 200 ether);
        usdc.mint(address(lending), 100 ether);
        usdc.mint(address(this), type(uint224).max-1);
        usdc.approve(address(lending), type(uint224).max-1);

        alice = address(0xa);
        vm.deal(alice, 100 ether);
        usdc.mint(alice, 100 ether);
        vm.prank(alice);
        usdc.approve(address(lending), 10000 ether);

        bob = address(0xb);
        vm.deal(bob, 100 ether);
        usdc.mint(bob, 100 ether);
        vm.prank(bob);
        usdc.approve(address(lending), 10000 ether);
    }

    function testDeposit() public 
    {
        vm.startPrank(bob);
        lending.deposit(address(usdc), 10 ether);
        assertEq(lending.atoken_balanceOf(bob), 10 ether);
        lending.deposit(address(usdc), 10 ether);
        assertEq(lending.atoken_balanceOf(bob), 20 ether);
    }

    function testborrow() public
    {
        vm.startPrank(bob);
        address(lending).call{value: 1 ether}(abi.encodeWithSignature("deposit(address,uint256)", address(0), 1 ether));
        lending.borrow(address(usdc), 50 ether);
        lending.borrow(address(usdc), 50 ether);
        assertEq(usdc.balanceOf(bob), 100 ether + 100 ether);
    }

    function testwithdraw() public
    {
        vm.prank(bob);
        lending.deposit(address(usdc), 10 ether);
        lending.deposit(address(usdc), 10 ether);
        assertEq(lending.atoken_balanceOf(bob), 10 ether);
        vm.prank(bob);
        vm.warp(1 days);
        lending.withdraw(address(usdc), 10 ether);
        lending.withdraw(address(usdc), 10 ether);
        assertEq(ERC20(address(usdc)).balanceOf(bob), 100 ether);
    
        vm.startPrank(alice);
        address(lending).call{value: 10 ether}(abi.encodeWithSignature("deposit(address,uint256)", address(0), 10 ether));
        lending.withdraw(address(0), 10 ether);
        assertEq(alice.balance, 100 ether);
    }

    function testrepay() public
    {
        vm.startPrank(bob);
        address(lending).call{value: 1 ether}(abi.encodeWithSignature("deposit(address,uint256)", address(0), 1 ether));
        console.log("bob.balance:", bob.balance);
        lending.borrow(address(usdc), 100 ether);
        vm.warp( 1 + 1 days);
        lending.repay(address(usdc), 100.1 ether);
        assertEq(bob.balance, 100 ether);
    }

    function testliquidate() public
    {
        vm.startPrank(bob);
        address(lending).call{value: 1 ether}(abi.encodeWithSignature("deposit(address,uint256)", address(0), 1 ether));
        lending.borrow(address(usdc), 100 ether);
        vm.stopPrank();
        
        usdc.approve(address(lending), 150 ether);
        dreamoracle.setPrice(address(usdc), 1.5 ether);

        vm.startPrank(alice);
        lending.liquidate(bob, address(usdc), 90 ether);
        console.log("alice's eth: ", alice.balance);
        console.log("alice's usdc: ", usdc.balanceOf(alice));
    }

    function testfee() public
    {
        uint256 before_balance = address(this).balance;
        vm.startPrank(bob);
        address(lending).call{value: 1 ether}(abi.encodeWithSignature("deposit(address,uint256)", address(0), 1 ether));
        lending.borrow(address(usdc), 100 ether);
        uint256 t = block.timestamp;
        vm.stopPrank();
        vm.warp(t + 50 days);
        vm.startPrank(bob);
        lending.repay(address(usdc), 105124483243475112358);
    }

    receive() payable external
    {
        
    }
}