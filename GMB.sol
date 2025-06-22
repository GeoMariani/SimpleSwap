// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title GMB Token
/// @notice ERC20 token with 2 decimals and public minting for testing purposes
/// @dev This token uses OpenZeppelin's ERC20 base and overrides decimals() to return 2
contract GMB is ERC20 {

    /// @notice Initializes the token with name and symbol
    /// @dev Token name is "Geo Mariani Beta", symbol is "GMB"
    constructor() ERC20("Geo Mariani Beta", "GMB") {}

    /// @notice Overrides the number of decimals for this token
    /// @dev Unlike the default 18, this token uses 2 decimals (e.g., 100 GMB = 100 * 10^2 = 10000 units)
    /// @return uint8 The number of decimals used (2)
    function decimals() public view virtual override returns (uint8) {
        return 2;
    }

    /// @notice Allows any address to mint tokens to any recipient
    /// @dev Use only for testing environments. Not safe for production.
    /// @param to The recipient address
    /// @param amount The amount to mint. For 1000 GMB, use: 1000 * 10**2 = 100000
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}