// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title SimpleSwap - Uniswap-like DEX for swapping two ERC20 tokens
/// @author geo
/// @notice Allows adding and removing liquidity, swapping tokens, and querying prices
contract SimpleSwap {
    address public tokenA;
    address public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    mapping(address => uint256) public liquidity;
    uint256 public totalLiquidity;

    /// @notice Initializes the contract with two ERC20 tokens
    /// @param _tokenA Address of token A (e.g., GMA)
    /// @param _tokenB Address of token B (e.g., GMB)
    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    /// @dev Updates the internal reserves
    function _updateReserves(uint256 _reserveA, uint256 _reserveB) internal {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    /// @dev Safe transfer from user to contract
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        require(IERC20(token).transferFrom(from, to, amount), "Transfer failed");
    }

    /// @notice Adds liquidity to the pool with both tokens
    /// @dev Calculates optimal proportions according to reserves
    /// @param _tokenA Address of token A
    /// @param _tokenB Address of token B
    /// @param amountADesired Desired amount of token A
    /// @param amountBDesired Desired amount of token B
    /// @param amountAMin Minimum acceptable amount of token A
    /// @param amountBMin Minimum acceptable amount of token B
    /// @param to Address that will receive liquidity tokens
    /// @param deadline Deadline timestamp for the transaction
    /// @return amountA Actual amount of token A used
    /// @return amountB Actual amount of token B used
    /// @return liquidityMinted Amount of liquidity minted
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidityMinted) {
        require(_tokenA == tokenA && _tokenB == tokenB, "Invalid token pair");
        require(block.timestamp <= deadline, "Transaction expired");

        if (reserveA == 0 && reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal >= amountAMin, "Insufficient A amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        if (totalLiquidity == 0) {
            liquidityMinted = sqrt(amountA * amountB);
        } else {
            liquidityMinted = min((amountA * totalLiquidity) / reserveA, (amountB * totalLiquidity) / reserveB);
        }

        require(liquidityMinted > 0, "Insufficient liquidity minted");
        liquidity[to] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        _updateReserves(IERC20(tokenA).balanceOf(address(this)), IERC20(tokenB).balanceOf(address(this)));

        return (amountA, amountB, liquidityMinted);
    }

    /// @notice Removes liquidity from the pool
    /// @param _tokenA Address of token A
    /// @param _tokenB Address of token B
    /// @param liquidityAmount Amount of LP tokens to burn
    /// @param amountAMin Minimum acceptable amount of token A
    /// @param amountBMin Minimum acceptable amount of token B
    /// @param to Address receiving the withdrawn tokens
    /// @param deadline Deadline for the transaction
    /// @return amountA Token A received
    /// @return amountB Token B received
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 liquidityAmount,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(_tokenA == tokenA && _tokenB == tokenB, "Invalid token pair");
        require(block.timestamp <= deadline, "Transaction expired");
        require(liquidity[msg.sender] >= liquidityAmount, "Not enough liquidity");

        amountA = (liquidityAmount * reserveA) / totalLiquidity;
        amountB = (liquidityAmount * reserveB) / totalLiquidity;

        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient output amounts");

        liquidity[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        require(IERC20(tokenA).transfer(to, amountA), "Transfer A failed");
        require(IERC20(tokenB).transfer(to, amountB), "Transfer B failed");

        _updateReserves(IERC20(tokenA).balanceOf(address(this)), IERC20(tokenB).balanceOf(address(this)));

        return (amountA, amountB);
    }

    /// @notice Swaps an exact amount of one token for another
    /// @param amountIn Amount of input token
    /// @param amountOutMin Minimum acceptable amount of output token
    /// @param path Array of token addresses [tokenIn, tokenOut]
    /// @param to Recipient address
    /// @param deadline Transaction deadline
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(path.length == 2, "Only direct swaps supported");
        require(block.timestamp <= deadline, "Transaction expired");

        address input = path[0];
        address output = path[1];
        require((input == tokenA && output == tokenB) || (input == tokenB && output == tokenA), "Invalid path");

        _safeTransferFrom(input, msg.sender, address(this), amountIn);

        (uint256 reserveIn, uint256 reserveOut) = input == tokenA ? (reserveA, reserveB) : (reserveB, reserveA);
        uint256 amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        address tokenOut = input == tokenA ? tokenB : tokenA;
        require(IERC20(tokenOut).transfer(to, amountOut), "Transfer failed");

        _updateReserves(IERC20(tokenA).balanceOf(address(this)), IERC20(tokenB).balanceOf(address(this)));
    }

    /// @notice Returns the price of tokenA expressed in tokenB (scaled by 1e18)
    /// @param _tokenA Address of token A
    /// @param _tokenB Address of token B
    /// @return price Price of tokenA in terms of tokenB
    function getPrice(address _tokenA, address _tokenB) external view returns (uint256 price) {
        require(_tokenA == tokenA && _tokenB == tokenB, "Invalid pair");
        require(reserveA > 0 && reserveB > 0, "Empty reserves");
        price = (reserveB * 1e18) / reserveA;
    }

    /// @notice Calculates the amount of output tokens received from a swap
    /// @dev Uses the basic reserves formula without fees: (amountIn * reserveOut) / (reserveIn + amountIn)
    /// @param amountIn Amount of input tokens to swap
    /// @param reserveIn Amount of reserves of the input token in the pool
    /// @param reserveOut Amount of reserves of the output token in the pool
    /// @return amountOut Estimated amount of output tokens to receive from the swap
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut) {
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    /// @notice Returns the square root using the Babylonian method
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// @notice Returns the smaller of two values
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
