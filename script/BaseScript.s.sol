// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";

contract BaseScript is Script {
  
    function setUp() public virtual {
        vm.createSelectFork(vm.envString("POLYGON_RPC_URL"));

        uint256 PrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(PrivateKey);
    }
}
       
