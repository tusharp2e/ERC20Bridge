// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GLDToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Gold", "GLD") {
        _mint(msg.sender, initialSupply);
    }

    function burn(address _owner, uint256 _amount) public {
        _burn(_owner, _amount);
    }

    function mint(address _owner, uint256 _amount) public {
        _mint(_owner, _amount);
    }
}