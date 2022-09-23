// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "src/Lending.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDC is ERC20 {
    uint public constant USDC_INITIAL_SUPPLY = 1000 ether;
    constructor() ERC20("USD Coin", "USDC") {
        super._mint(msg.sender, USDC_INITIAL_SUPPLY);
    }
}

contract ETH is ERC20 {
    uint public constant USDC_INITIAL_SUPPLY = 1000 ether;
    constructor() ERC20("ETH coin", "ETH") {
        super._mint(msg.sender, USDC_INITIAL_SUPPLY);
    }
}

contract LendingTest is Test {

    MyLend bank;
    DreamOracle oracle;
    ERC20 usdc;
    ERC20 eth;

    function setUp() public {
        oracle = new DreamOracle();
        usdc = new USDC();
        eth = new ETH();
        bank = new MyLend(address(usdc), address(eth),address(oracle));
        vm.deal(address(bank), 10 ether);
        usdc.transfer(address(bank), 10 ether);   
        oracle.setPrice(address(eth),10 ether);     

    }

    function testDepositBasic1() public {
        address actor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(actor, 1 ether);
        usdc.transfer(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;

        vm.startPrank(actor);
        vm.warp(0);
        usdc.approve(address(bank), 1 ether);
        bank.deposit(address(usdc), 1 ether);
        vm.warp(1 days);
        balPrev = usdc.balanceOf(actor);
        bank.withdraw(address(usdc), 1 ether);
        balAfter = usdc.balanceOf(actor);
        assertEq(balAfter - balPrev, 1 ether);
    }

    function testDepositBasic2() public {
        address actor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(actor, 1 ether);
        eth.transfer(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;
        usdc.transfer(borrower,0.0005 ether);

        vm.startPrank(actor);
        vm.warp(0);
        usdc.approve(address(bank), 10 ether);
        bank.deposit(address(usdc), 1 ether);
        uint256 bal1 = usdc.balanceOf(address(bank)); // 11ether
        vm.stopPrank();

        vm.startPrank(borrower);
        vm.warp(0);
        eth.approve(address(bank), 1 ether);
        bank.deposit(address(eth), 1 ether);
        bank.borrow(address(usdc), 0.5 ether);
        
        vm.warp(1 days);

        eth.approve(address(bank), 10 ether);
        usdc.approve(address(bank), 10 ether);
        usdc.balanceOf(borrower);
        bank.repay(address(usdc), 0.5005 ether);
        usdc.balanceOf(borrower);

        vm.stopPrank();
        vm.startPrank(actor);
        
        balPrev = usdc.balanceOf(actor);
        bank.withdraw(address(usdc), 0.5005 ether);
        balAfter = usdc.balanceOf(actor);
        assertEq(balAfter - balPrev, 0.5005 ether);
    }

    function testLendBasic() public {
        address actor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(actor, 10 ether);
        usdc.transfer(borrower, 1 ether);
        eth.transfer(borrower, 3 ether);
        vm.deal(actor, 10 ether);
        vm.deal(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;
        uint256 etherAmount;
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(actor);
        vm.warp(0);
        balPrev = usdc.balanceOf(actor);
        etherAmount = oracle.getPrice(address(usdc)) * 1 ether * 2; //4
        usdc.approve(address(bank), 10 ether);    
        bank.deposit(address(usdc), etherAmount);
        uint bal1 = usdc.balanceOf(actor); //10-4 = 6 ether
        bank.give(actor, address(usdc)); //4 ether

        vm.stopPrank();
        vm.startPrank(borrower);

        uint bal2= usdc.balanceOf(borrower);
        eth.approve(address(bank), 10 ether);    
        bank.deposit(address(eth), 3 ether);
        bank.borrow(address(usdc), 1 ether); // 1 ether 빌림
        balAfter = usdc.balanceOf(borrower); // 2 ether
        assertEq(bal2 + 1 ether, balAfter);
        
        vm.warp(1 days);
        
        balPrev = usdc.balanceOf(borrower);
        usdc.approve(address(bank), 1.001 ether);
        bank.repay(address(usdc), 0.5 ether);
        balAfter = usdc.balanceOf(borrower);

        balPrev = usdc.balanceOf(borrower);
        bank.repay(address(usdc), 0.501 ether);
        balAfter = usdc.balanceOf(borrower);
    }

function testLendBasic2() public {
        address actor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(actor, 10 ether);
        usdc.transfer(borrower, 1 ether);
        eth.transfer(borrower, 3 ether);
        vm.deal(actor, 10 ether);
        vm.deal(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;
        uint256 etherAmount;
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(actor);
        vm.warp(0);
        balPrev = usdc.balanceOf(actor);
        etherAmount = oracle.getPrice(address(usdc)) * 1 ether * 2; //4
        usdc.approve(address(bank), 10 ether);    
        bank.deposit(address(usdc), etherAmount);
        uint bal1 = usdc.balanceOf(actor); //10-4 = 6 ether
        bank.give(actor, address(usdc)); //4 ether

        vm.stopPrank();
        vm.startPrank(borrower);

        uint bal2= usdc.balanceOf(borrower);
        eth.approve(address(bank), 10 ether);    
        bank.deposit(address(eth), 3 ether);
        bank.borrow(address(usdc), 1 ether); // 1 ether 빌림
        balAfter = usdc.balanceOf(borrower); // 2 ether
        assertEq(bal2 + 1 ether, balAfter);
        
        vm.warp(1 days);
        
        balPrev = usdc.balanceOf(borrower); //2
        usdc.approve(address(bank), 1.001401 ether);
        bank.repay(address(usdc), 0.6 ether);
        balAfter = usdc.balanceOf(borrower); // 2.0

        vm.warp(2 days);

        bank.print();
        balPrev = usdc.balanceOf(borrower); //1.4
        bank.repay(address(usdc), 0.401401 ether);
        balAfter = usdc.balanceOf(borrower);
    }

    function testLiquidateBasic1() public {
        address actor1 = address(0x11);
        address actor2 = address(0x22);
        usdc.transfer(actor1, 10 ether);
        usdc.transfer(actor2, 10 ether);
        vm.deal(actor1, 10 ether);
        uint256 balPrev;
        uint256 balAfter;
        uint256 etherAmount;
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(actor1);
        vm.warp(0);
        balPrev = usdc.balanceOf(actor1);
        etherAmount = oracle.getPrice(address(usdc)) * 1 ether * 2;
        bank.deposit{value: etherAmount}(address(0), 0);
        bank.borrow(address(usdc), 1 ether);
        balAfter = usdc.balanceOf(actor1);
        assertEq(balPrev + 1 ether, balAfter);
        vm.warp(1 days);
        vm.stopPrank();

        // lower the price of ETH so that liquidation is triggered
        oracle.setPrice(address(usdc), 4);
        vm.startPrank(actor2);
        balPrev = usdc.balanceOf(actor2);
        usdc.approve(address(bank), 10 ether);
        bank.liquidate(actor1, address(usdc), etherAmount);
        balAfter = usdc.balanceOf(actor2);
        assertGt(balPrev, balAfter);
        vm.stopPrank();
    }

    function testLiquidateBasic2() public {
        address actor1 = address(0x11);
        address actor2 = address(0x22);
        usdc.transfer(actor1, 10 ether);
        usdc.transfer(actor2, 10 ether);
        vm.deal(actor1, 10 ether);
        uint256 balPrev;
        uint256 balAfter;
        uint256 etherAmount;
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(actor1);
        vm.warp(0);
        balPrev = usdc.balanceOf(actor1);
        etherAmount = oracle.getPrice(address(usdc)) * 1 ether * 2;
        bank.deposit{value: etherAmount}(address(0), 0);
        bank.borrow(address(usdc), 1 ether);
        balAfter = usdc.balanceOf(actor1);
        assertEq(balPrev + 1 ether, balAfter);
        vm.warp(1 days);
        vm.stopPrank();

        // liquidation is not triggered
        vm.startPrank(actor2);
        balPrev = usdc.balanceOf(actor2);
        usdc.approve(address(bank), 10 ether);
        bank.liquidate(actor1, address(usdc), etherAmount);
        balAfter = usdc.balanceOf(actor2);
        assertEq(balPrev, balAfter);
        vm.stopPrank();
    }

    function testDoubleDeposit() public {
        address actor = address(0x11);
        uint256 balPrev;
        uint256 balAfter;
        usdc.transfer(actor, 10 ether);
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(actor);
        usdc.approve(address(bank), 2 ether);
        balPrev = usdc.balanceOf(address(bank));
        bank.deposit(address(usdc), 1 ether);
        bank.deposit(address(usdc), 1 ether);
        balAfter = usdc.balanceOf(address(bank));
        assertEq(balAfter, balPrev + 2 ether);
    }

    function testLiquidatePartial() public {
        address actor1 = address(0x11);
        address actor2 = address(0x22);
        address actor3 = address(0x33);
        usdc.transfer(actor1, 10 ether);
        usdc.transfer(actor2, 10 ether);
        usdc.transfer(actor3, 10 ether);
        vm.deal(actor1, 10 ether);
        uint256 balPrev;
        uint256 balAfter;
        uint256 etherAmount;
        uint256 liquidateUsdc1;
        uint256 liquidateUsdc2;
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(actor1);
        vm.warp(0);
        balPrev = usdc.balanceOf(actor1);
        etherAmount = oracle.getPrice(address(usdc)) * 1 ether * 2;
        bank.deposit{value: etherAmount}(address(0), 0);
        bank.borrow(address(usdc), 1 ether);
        balAfter = usdc.balanceOf(actor1);
        assertEq(balPrev + 1 ether, balAfter);
        vm.warp(1 days);
        vm.stopPrank();

        // lower the price of ETH so that liquidation is triggered
        oracle.setPrice(address(usdc), 4);
        vm.startPrank(actor2);
        usdc.approve(address(bank), 10 ether);
        balPrev = usdc.balanceOf(actor2);
        bank.liquidate(actor1, address(usdc), etherAmount / 2);
        balAfter = usdc.balanceOf(actor2);
        liquidateUsdc1 = balPrev - balAfter;
        vm.stopPrank();

        vm.startPrank(actor3);
        usdc.approve(address(bank), 10 ether);
        balPrev = usdc.balanceOf(actor3);
        bank.liquidate(actor1, address(usdc), etherAmount / 4);
        balAfter = usdc.balanceOf(actor3);
        liquidateUsdc2 = balPrev - balAfter;
        vm.stopPrank();
        
        assertEq(liquidateUsdc1, liquidateUsdc2 * 2);
    }
}