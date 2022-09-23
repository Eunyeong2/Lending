//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DreamOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MyLend is IERC20, ERC20 {

    DreamOracle public oracle;
    mapping(address => mapping(address => uint256)) public deposits; // 예금한 주소, 예금한 토큰, 예금한 값 저장
    mapping(address => mapping(address => uint256)) public borrows; // 빌린 주소, 빌린 토큰, 빌린 양 저장
    mapping(address => uint256) public times; // block.timestamp
    //uint time; // 현재 시간
    address public ETH;
    address public USDC;

    uint256 private reserve0;
    uint256 private reserve1;

    uint private unlocked = 1;

    uint time;

    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _token0, address _token1) ERC20("USDC", "USD"){
        ETH = _token0;
        USDC = _token1;
        time = block.timestamp;
    }

    function deposit(address tokenAddress, uint256 amount) external payable { // 입금
        require(IERC20(tokenAddress).balanceOf(msg.sender) > amount, "msg.sender doesn't have enough amount!");
        //deposits[msg.sender] = tokenAddress;
        deposits[msg.sender][tokenAddress] = amount; //예금 정보 저장 완료
        IERC20(tokenAddress).transfer(address(this), amount); // pool에 돈 전달
        times[tokenAddress] = block.timestamp; // 입금한 시간 저장
    }

    function borrow(address tokenAddress, uint256 amount) external payable { //대출. tokenAddress : 담보 토큰. amount : 담보의 양
        require(IERC20(tokenAddress).balanceOf(address(this)) > amount, "Token is under borrow amount"); //pool에 남아 있는 돈 계산
        uint256 mortgage = oracle.getPrice(tokenAddress); //담보 가격 가져오기
        //require(mortgage >= IERC20(USDC).balanceOf(address.this)); // 담보의 가격이 더 세야 함
        uint256 limit = mortgage/2; //50% 비율로 빌려주기
        if (limit > amount){
            borrows[msg.sender][tokenAddress] = amount;
        } else{
            borrows[msg.sender][tokenAddress] = limit;
        }
        IERC20(USDC).transfer(msg.sender, borrows[msg.sender][tokenAddress]);
    }

    function repay(address tokenAddress, uint256 amount) external payable { //상환
        require(IERC20(tokenAddress).balanceOf(msg.sender) > amount, "msg.sender doesn't have enough amount!");
        uint day = block.timestamp - times[tokenAddress] / 24; //이자율 계산을 위한 interests
        borrows[msg.sender][tokenAddress] += (borrows[msg.sender][tokenAddress] * 1001 ^ day) / (1000 ^ day); //이자율 계산해서 총액 더함 (이자까지 합해서 갚아야 하니까)
        IERC20(tokenAddress).transfer(address(this), amount); // 수수료 합쳐서 청산
        require(amount < borrows[msg.sender][tokenAddress]);
        IERC20(USDC).transfer(msg.sender, amount);
        borrows[msg.sender][tokenAddress] -= amount;
        times[tokenAddress]=block.timestamp;
    }

    function liquidate(address user, address tokenAddress, uint256 amount) external payable { //청산
        uint256 mortgage = oracle.getPrice(tokenAddress); //현재 담보 가격 가져오기
        require(mortgage <= borrows[user][tokenAddress] * 3 / 4, "Liquidation threshold is 75%");
        _burn(msg.sender, borrows[msg.sender][tokenAddress]);
        borrows[user][tokenAddress] -= amount;
    }

    function withdraw(address tokenAddress, uint256 amount) external payable{
        require(deposits[msg.sender][tokenAddress] >= amount, "Lack of deposit amounts");
        deposits[msg.sender][tokenAddress] -= amount;
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }
}