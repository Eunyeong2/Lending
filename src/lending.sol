//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DreamOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MyLend is IERC20, ERC20 {

    DreamOracle public oracle;
    mapping(address => uint256) public interests; // 이자 계산한 값 금액 저장
    mapping(address => uint256) public borrows; // 빌린 금액 저장
    mapping(address => uint256) public times; // block.timestamp
    //uint time; // 현재 시간
    address public ETH;
    address public USDC;

    uint256 private reserve0;
    uint256 private reserve1;

    uint private unlocked = 1;

    uint private threshold = 3/4;

    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _token0, address _token1) ERC20("Enong", "ENO"){
        ETH = _token0;
        USDC = _token1;
        time = block.timestamp;
    }

    function deposit(address tokenAddress, uint256 amount) external { //입금
        require(IERC20(tokenAddress).balanceOf(msg.sender) > amount, "msg.sender doesn't have enough amount!");
        IERC20(tokenAddress).transfer(address(this), amount);
        times[tokenAddress] = block.timestamp;
    }

    function calculate(address tokenAddress) internal returns(uint256 _reserve) {
        uint days = (block.timestamp - times[tokenAddress]) / 24 ;
        for (i=0;i<days;i++){
            _reserve = IERC20(tokenAddress).balanceOf(address(this));
            _reserve = (_reserve * 1001 ^ days) / 1000 ^ days;
        }
        interests[tokenAddress] = _reserve;
        borrows[msg.sender] += _reserve;
    }

    function borrow(address tokenAddress, uint256 amount) external { //대출
        //tokenAddress : 담보. amount : 대출할 양
        uint256 mortgage = oracle.getPrice(tokenAddress); //담보 가격 가져오기
        require(mortgage >= IERC20(USDC).balanceOf(address.this)); // 담보의 가격이 더 세야 함
        IERC20(USDC).transfer(msg.sender, mortgage/2); //50% 비율로 빌려주기
        borrows[msg.sender] += mortgage/2;
    }

    function repay(address tokenAddress, uint256 amount) external { //상환
        require(IERC20(tokenAddress).balanceOf(msg.sender) > amount, "msg.sender doesn't have enough amount!");
        uint days = block.timestamp - time / 24; //이자율 계산을 위한 interests
        IERC20(tokenAddress).transfer(address(this), amount); // 수수료 합쳐서 청산
        borrows[msg.sender] -= amount;
    }

    function liquidate(address user, address tokenAddress, uint256 amount) external { //청산

    }
}