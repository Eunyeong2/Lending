//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/forge-std/src/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./DreamOracle.sol";
import "./Math.sol";

contract MyLend is ERC20{

    address private oracle;
    mapping(address => uint256) public atokens; //Atoken
    mapping(address => borrows) public borrowers;
    address public USDC;
    address public ETH = address(0);

    struct borrows{
        uint256 borrowTime;
        uint256 borrowAmount;
        uint256 orimortgages;
        uint256 mortgages;
        uint256 interests;
    }

    uint256 private total;

    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address usdc, address _oracle) ERC20("AToken", "ATK"){
        USDC = usdc;
        oracle = _oracle;
    }

    function deposit(address tokenAddress, uint256 amount) external payable lock { // 입금
        require(tokenAddress == address(0) || tokenAddress == USDC, "tokenAddress is different");

        if (tokenAddress == USDC){
            require(ERC20(tokenAddress).balanceOf(msg.sender) >= amount, "msg.sender doesn't have enough amount!");
            require(ERC20(tokenAddress).transferFrom(msg.sender, address(this), amount)); // pool에 돈 전달
            _mint(msg.sender, amount);
            atokens[msg.sender] += amount;
        } else{
            require(msg.value >= amount);
            borrowers[msg.sender].mortgages += amount; //담보 저장
            borrowers[msg.sender].orimortgages += amount;
        }
    }

    function atoken_balanceOf(address _who) public view returns (uint256 result){
        result = atokens[_who];
    }

    function borrow(address tokenAddress, uint256 amount) external payable {
        require(ERC20(tokenAddress).balanceOf(address(this)) >= amount, "Token is under borrow amount"); //pool에 남아 있는 돈 계산
        require(tokenAddress == USDC, "You can borrow only USDC");
        
        uint256 mortgage =  borrowers[msg.sender].mortgages * DreamOracle(oracle).getPrice(address(0)) / 10**18;//담보 가격 가져오기
        uint256 limit = mortgage/2; //LTV
        require( amount <= limit, "Too much amount");

        if (block.timestamp - borrowers[msg.sender].borrowTime >= 1 days){
            calculate(borrowers[msg.sender].borrowTime, block.timestamp);
        }
        borrowers[msg.sender].borrowAmount += amount;

        if (limit - amount == 0){
            borrowers[msg.sender].mortgages = 0;
        } else{
            uint k = limit / (limit - amount); // 남아 있는 담보 양 계산을 위한 비율
            borrowers[msg.sender].mortgages = borrowers[msg.sender].mortgages * 1 / k;
        }

        ERC20(USDC).transfer(msg.sender, amount);

        borrowers[msg.sender].borrowTime = block.timestamp;
    }

    function repay(address tokenAddress, uint256 amount) external payable { //상환
        require(tokenAddress == USDC, "Repaying needs only USDC");
        uint fee = 0;
        if (block.timestamp - borrowers[msg.sender].borrowTime >= 1 days){
            fee = calculate(borrowers[msg.sender].borrowTime, block.timestamp);
        }

        require(ERC20(tokenAddress).balanceOf(msg.sender) >= amount, "msg.sender doesn't have enough amount!");

        ERC20(USDC).transferFrom(msg.sender, address(this), amount);

        borrowers[msg.sender].borrowAmount -= amount;
        payable(msg.sender).transfer(amount * 2 / DreamOracle(oracle).getPrice(address(0)) * 10**18);
        borrowers[msg.sender].mortgages += amount;
    }

    function liquidate(address user, address tokenAddress, uint256 amount) external payable { //청산
        require(tokenAddress == USDC, "liquidate: token error");
        require(borrowers[user].borrowAmount >= amount);

        uint256 limit = borrowers[user].orimortgages * DreamOracle(oracle).getPrice(address(0)) * 3 / 10**18 /4;
        console.log("limit: ", limit);

        require(borrowers[user].borrowAmount * DreamOracle(oracle).getPrice(address(tokenAddress)) / 10**18 >= limit, "threshold");
        console.log(borrowers[user].borrowAmount * DreamOracle(oracle).getPrice(address(tokenAddress)) / 10**18);
        //uint256 mortgageAmount = amount * 10**18 * 2 * DreamOracle(oracle).getPrice(address(tokenAddress))/DreamOracle(oracle).getPrice(address(0));
        uint256 mortgageAmount = amount / (DreamOracle(oracle).getPrice(address(0)) / 1 ether);
        //mortgageAmount += mortgageAmount / 1000 * 5;

        require( borrowers[user].orimortgages >= mortgageAmount );
        borrowers[user].orimortgages -= mortgageAmount;

        ERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        payable(msg.sender).transfer(mortgageAmount);
    }

    function withdraw(address tokenAddress, uint256 amount) external payable {
        if (tokenAddress == address(0)){ // ETH withdraw
            require(borrowers[msg.sender].mortgages >= amount, "Your mortgages are using");
            borrowers[msg.sender].mortgages -= amount;
            borrowers[msg.sender].orimortgages -= amount;
            payable(msg.sender).transfer(amount);
        }
        else{ // usdc withdraw
            uint rate = ERC20(tokenAddress).balanceOf(address(this)) * balanceOf(msg.sender) / totalSupply();
            if (amount % rate == 0){
                _burn(msg.sender, balanceOf(msg.sender) * amount/rate);
                }
            else{
                _burn(msg.sender, balanceOf(msg.sender) * amount/rate +1);
                }
            ERC20(tokenAddress).transfer(msg.sender, amount);
            }
        }

    function calculate(uint beforetime, uint aftertime) internal lock returns(uint256 fee) {
        uint _days =  (aftertime - beforetime) / 1 days;
        fee = borrowers[msg.sender].borrowAmount;
        for (uint i=0; i < _days; i++){
            fee = fee * 1001 / 1000;
        }
        fee -= borrowers[msg.sender].borrowAmount;
        borrowers[msg.sender].borrowTime = block.timestamp;
        borrowers[msg.sender].borrowAmount += fee;
    }
}