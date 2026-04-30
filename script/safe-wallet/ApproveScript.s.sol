// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ApproveScript is BaseScript {
    address PUSD = 0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB;

    address V2Exchange = 0xE111180000d2663C0091e4f400237545B87B996B;

    function run() external {
        // approve
        // approvePUSDToV2Exchange();

        queryAllowance();
    }

    // 1. query allowance
    function queryAllowance() public view {
        address safe = 0xE51282BdEeeb988406B3f969a6277b02bAdc2e19;
        uint256 allownace = IERC20(PUSD).allowance(safe, V2Exchange);
        console2.log("allownace", allownace);
    }

    function approvePUSDToV2Exchange() public {
        IERC20(PUSD).approve(V2Exchange, 1000e6);
    }
}
