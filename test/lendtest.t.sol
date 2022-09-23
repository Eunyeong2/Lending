// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/Lending.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract coin is IERC20, ERC20{
    constructor () ERC20("USD", "USDC"){   
    }
}
contract MyLendTest is Test{
    MyLend public mylend;

}