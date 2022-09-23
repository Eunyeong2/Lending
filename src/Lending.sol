//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../lib/forge-std/src/console.sol";
import "./DreamOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MyLend is IERC20, ERC20 {

    address private oracle;
    mapping(address => mapping(address => uint256)) public deposits; // 예금한 주소, 예금한 토큰, 예금한 값 저장
    mapping(address => mapping(address => uint256)) public borrows; // 빌린 주소, 빌린 토큰, 빌린 양 저장
    mapping(address => mapping(address => uint256)) public interests; // tokenAddress , 빌린 계좌 => 이자 저장
    mapping(address => uint256) public times; // block.timestamp
    mapping(address => uint256) public mortgages; //담보
    address public USDC;
    address public ETH;

    uint256 private total;
    uint256 private total_deposits;
    uint256 private total_interests;

    address private deposit_address;

    uint private unlocked = 1;

    uint time;

    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _token0, address _token1, address _oracle) ERC20("USD", "USDC"){
        USDC = _token0;
        ETH = _token1;
        time = block.timestamp;
        oracle = _oracle;
    }

    function give(address _who, address _token) public returns(uint256 __total){
        __total = deposits[_who][_token];
    }

    function print() public returns(uint _interests){
        _interests = total_interests;
    }

    function print2() public returns(uint _total){
        _total = total;
    }

    function give2(address _who, address _token) public returns(uint256 ___total){
        ___total = borrows[_who][_token];
    }

    function deposit(address tokenAddress, uint256 amount) external payable lock { // 입금
        require(tokenAddress == USDC || tokenAddress == ETH, "tokenAddress is different");
        //require(msg.value != 0, "msg.value is zero");
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= amount, "msg.sender doesn't have enough amount!");

        if (tokenAddress == USDC){
            deposits[msg.sender][tokenAddress] += amount; //예금 정보 저장 완료
            total_deposits += amount;
            deposit_address = msg.sender;
        } else{
            mortgages[msg.sender] += amount; //담보 저장
        }
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount); // pool에 돈 전달
    }

    function borrow(address tokenAddress, uint256 amount) external payable { //대출. tokenAddress : 담보 토큰. amount : 담보의 양
        require(IERC20(tokenAddress).balanceOf(address(this)) >= amount, "Token is under borrow amount"); //pool에 남아 있는 돈 계산
        require(tokenAddress == USDC, "You can borrow only USDC");
        
        uint256 mortgage = DreamOracle(oracle).getPrice(ETH) * mortgages[msg.sender]; //담보 가격 가져오기
        uint256 limit = mortgage/2; //50% 비율로 빌려주기

        if (limit > amount){
            borrows[msg.sender][tokenAddress] = amount;
        } else{
            borrows[msg.sender][tokenAddress] = limit;
        }

        IERC20(USDC).transfer(msg.sender, borrows[msg.sender][tokenAddress]);

        total+=borrows[msg.sender][tokenAddress];
        times[msg.sender] = block.timestamp; // 빌린 시간 저장
    }

    function repay(address tokenAddress, uint256 amount) external payable { //상환
        require(tokenAddress == USDC, "Repaying needs only USDC");
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= amount, "msg.sender doesn't have enough amount!");
        uint time_now = times[msg.sender];
        times[msg.sender]=block.timestamp; // 시간 갱신
        calculate(tokenAddress, time_now, block.timestamp); // 이자 갱신
        IERC20(USDC).transferFrom(msg.sender, address(this), amount); // 수수료 합쳐서 전달
        borrows[msg.sender][tokenAddress] -= amount;
        IERC20(ETH).transfer(msg.sender, amount);
        //total -= amount;
    }

    function liquidate(address user, address tokenAddress, uint256 amount) external payable { //청산
        require(tokenAddress == ETH, "Liquidating needs only ETH");
        uint256 mortgage = DreamOracle(oracle).getPrice(tokenAddress) * mortgages[msg.sender]; //현재 담보 가격 가져오기
        require(mortgage * 3 / 4 <= borrows[user][tokenAddress], "Liquidation threshold is 75%");
        //mortgage 가치만큼 

        _burn(msg.sender, borrows[msg.sender][tokenAddress]);
        borrows[user][tokenAddress] -= amount;
    }

    function withdraw(address tokenAddress, uint256 amount) external payable{
        //require(deposits[msg.sender][tokenAddress] >= amount);
        if( total_interests == 0){ // 축적된 이자가 없을 때 원금만 돌려줌.
            require(deposits[msg.sender][tokenAddress] >= amount, "Lack of deposit amounts");
            deposits[msg.sender][tokenAddress] -= amount;
            total_deposits -= amount;
            IERC20(tokenAddress).transfer(msg.sender, amount);
        } else {
            //calculate(tokenAddress,times[msg.sender], block.timestamp);
            require(deposits[msg.sender][tokenAddress] >= amount, "Lack of deposit amounts2");
            require((deposits[msg.sender][tokenAddress] + total_interests * (deposits[msg.sender][tokenAddress] / total_deposits)) >= amount, "Lack of deposit amounts3");
            deposits[msg.sender][tokenAddress] += total_interests * (deposits[msg.sender][tokenAddress] / total_deposits);
            if(deposits[msg.sender][tokenAddress] > amount){
                deposits[msg.sender][tokenAddress] -= amount + total_interests * (deposits[msg.sender][tokenAddress] / total_deposits);
                IERC20(tokenAddress).transfer(msg.sender, amount + total_interests * (deposits[msg.sender][tokenAddress] / total_deposits));
                total_deposits -= amount;
            } else{
                calculate(tokenAddress,times[msg.sender], block.timestamp);
                deposits[msg.sender][tokenAddress] -= amount + total_interests * (deposits[msg.sender][tokenAddress] / total_deposits);
                IERC20(tokenAddress).transfer(msg.sender, amount + total_interests * (deposits[msg.sender][tokenAddress] / total_deposits));
                total_deposits -= amount;
            }
        }
    }

    function calculate(address tokenAddress, uint beforetime, uint aftertime) internal lock {
        uint _days =  (aftertime - beforetime) / 1 days;
        if (_days != 0){
            total_interests += borrows[msg.sender][tokenAddress] * (( 1001**_days / 1000**_days) -1);
            borrows[msg.sender][tokenAddress] = (borrows[msg.sender][tokenAddress] * (1001 ** _days)) / (1000 ** _days);
            interests[msg.sender][tokenAddress] = borrows[msg.sender][tokenAddress];
        }
    }
}