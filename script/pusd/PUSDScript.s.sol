// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {console2} from "forge-std/console2.sol";
import {CollateralToken} from "ctf-exchange-v2/collateral/CollateralToken.sol";

contract PUSDScript is BaseScript {

    address PUSD = 0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB;
    function run() external {

        console2.log(block.number);

        CollateralToken pusd = CollateralToken(PUSD);
        console2.log(pusd.name());
        console2.log(pusd.symbol());
        //USDC
        console2.log("USDC ",pusd.USDC());
        //USDCE
        console2.log("USDCE ",pusd.USDCE());
        //VAULT
        console2.log("VAULT ",pusd.VAULT());
        

    }
}