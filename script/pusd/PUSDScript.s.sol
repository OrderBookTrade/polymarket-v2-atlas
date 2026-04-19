// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.s.sol";
import {console2} from "forge-std/console2.sol";
import {CollateralToken} from "ctf-exchange-v2/collateral/CollateralToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CollateralOnramp} from "ctf-exchange-v2/collateral/CollateralOnramp.sol";
import {CollateralOfframp} from "ctf-exchange-v2/collateral/CollateralOfframp.sol";

contract PUSDScript is BaseScript {
    address PUSD = 0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB;

    address ONRAMP = 0x93070a847efEf7F70739046A929D47a521F5B8ee;
    address OFFRAMP = 0x2957922Eb93258b93368531d39fAcCA3B4dC5854;
    address USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address USDCE = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    function run() external {
        // 1. get PUSD config
        // getPusdConfig();

        //2. approve usdc | usdcE
        // approveUSDCToOnramp();
        // approveUSDCEToOnramp();

        // 3.wrap
        // wrapToPUSD();

        // 4. apporve PUSD to OFFRAMP
        // approvePUSDToOfframp();

        // 5. unwrap
        // unwrapPUSDToUSDC();

        // 6. pusd transfer
        PUSDTransfertoSafe();

    }

    function getPusdConfig() public view {
        console2.log(block.number);

        CollateralToken pusd = CollateralToken(PUSD);
        console2.log(pusd.name());
        console2.log(pusd.symbol());
        //USDC
        console2.log("USDC ", pusd.USDC());
        //USDCE
        console2.log("USDCE ", pusd.USDCE());
        //VAULT
        console2.log("VAULT ", pusd.VAULT());
    }

    function approveUSDCEToOnramp() public {
        ERC20(USDCE).approve(ONRAMP, type(uint256).max);
    }

    function approveUSDCToOnramp() public {
        ERC20(USDC).approve(ONRAMP, type(uint256).max);
    }

    function wrapToPUSD() public {
        CollateralOnramp onramp = CollateralOnramp(ONRAMP);

        uint256 amount = 0.1e6;
        onramp.wrap(USDCE, user_address, amount);
    }

    // Approve PUSD to OFFRAMP
    function approvePUSDToOfframp() public {
        ERC20(PUSD).approve(OFFRAMP, 100e6);
    }

    //forge script script/pusd/PUSDScript.s.sol -vvvv --broadcast --with-gas-price 1000gwei --priority-gas-price 1000gwei

    function unwrapPUSDToUSDC() public {
        CollateralOfframp offramp = CollateralOfframp(OFFRAMP);
        uint256 amount = 0.1e6;
        offramp.unwrap(USDCE, user_address, amount);
    }

    // https://docs.polymarket.com/concepts/pusd#example

    // const wrapHash = await walletClient.writeContract({
    //   address: ONRAMP,
    //   abi: parseAbi(["function wrap(address _asset, address _to, uint256 _amount)"]),
    //   functionName: "wrap",
    //   args: [USDCE, account.address, amount],
    // });
    // await publicClient.waitForTransactionReceipt({ hash: wrapHash });


    function PUSDTransfertoSafe() public {
        // change this to safe wallet address
        address safeWalletAddress = user_address;   
        ERC20(PUSD).transfer(safeWalletAddress, 2e6);
    }
}
