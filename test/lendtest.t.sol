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
        address depositor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(depositor, 1 ether);
        usdc.transfer(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;

        vm.startPrank(depositor);
        vm.warp(0);
        usdc.approve(address(bank), 1 ether);
        bank.deposit(address(usdc), 1 ether);
        vm.warp(1 days);
        balPrev = usdc.balanceOf(depositor);
        bank.withdraw(address(usdc), 1 ether);
        balAfter = usdc.balanceOf(depositor);
        assertEq(balAfter - balPrev, 1 ether);
    }

    function testDepositBasic2() public {
        address depositor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(depositor, 1 ether);
        eth.transfer(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;
        usdc.transfer(borrower,0.0005 ether);

        vm.startPrank(depositor);
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
        vm.startPrank(depositor);
        
        balPrev = usdc.balanceOf(depositor);
        bank.withdraw(address(usdc), 0.5005 ether);
        balAfter = usdc.balanceOf(depositor);
        assertEq(balAfter - balPrev, 0.5005 ether);
    }

    function testLendBasic() public {
        address depositor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(depositor, 10 ether);
        usdc.transfer(borrower, 1 ether);
        eth.transfer(borrower, 3 ether);
        vm.deal(depositor, 10 ether);
        vm.deal(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;
        uint256 etherAmount;
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(depositor);
        vm.warp(0);
        balPrev = usdc.balanceOf(depositor);
        etherAmount = oracle.getPrice(address(usdc)) * 1 ether * 2; //4
        usdc.approve(address(bank), 10 ether);    
        bank.deposit(address(usdc), etherAmount);
        uint bal1 = usdc.balanceOf(depositor); //10-4 = 6 ether

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
        address depositor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(depositor, 10 ether);
        usdc.transfer(borrower, 1 ether);
        eth.transfer(borrower, 3 ether);
        vm.deal(depositor, 10 ether);
        vm.deal(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;
        uint256 etherAmount;
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(depositor);
        vm.warp(0);
        balPrev = usdc.balanceOf(depositor);
        etherAmount = oracle.getPrice(address(usdc)) * 1 ether * 2; //4
        usdc.approve(address(bank), 10 ether);    
        bank.deposit(address(usdc), etherAmount);
        uint bal1 = usdc.balanceOf(depositor); //10-4 = 6 ether

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

        balPrev = usdc.balanceOf(borrower); //1.4
        bank.repay(address(usdc), 0.401401 ether);
        balAfter = usdc.balanceOf(borrower);
    }

    function testLiquidateBasic1() public {
        address depositor = address(0x11);
        address borrower = address(0x12);
        usdc.transfer(depositor, 100 ether);
        usdc.transfer(borrower, 1 ether);
        eth.transfer(borrower, 4 ether);
        vm.deal(depositor, 100 ether);
        vm.deal(borrower, 1 ether);
        uint256 balPrev;
        uint256 balAfter;
        uint256 etherAmount;
        oracle.setPrice(address(usdc), 2);

        vm.startPrank(depositor);
        vm.warp(0);
        balPrev = usdc.balanceOf(depositor);
        usdc.approve(address(bank), 100 ether);    
        bank.deposit(address(usdc), 100 ether);
        uint bal1 = usdc.balanceOf(depositor); //0 ether

        vm.stopPrank();
        vm.startPrank(borrower);

        uint bal2= usdc.balanceOf(borrower); //1 ether
        eth.approve(address(bank), 4 ether);    
        bank.deposit(address(eth), 4 ether); // 20 ether 까지 가능
        bank.borrow(address(usdc), 16 ether); // 16 ether 빌림
        balAfter = usdc.balanceOf(borrower); // 17 ether

        vm.stopPrank();
        oracle.setPrice(address(eth), 5 ether); //20ether의 가치

        vm.startPrank(borrower);     
        eth.approve(address(bank), 3 ether);    
        bank.liquidate(borrower, address(usdc), 3 ether);
    }
}