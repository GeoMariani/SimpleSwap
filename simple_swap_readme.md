# SimpleSwap

**SimpleSwap** es un contrato inteligente en Solidity que implementa un DEX (exchange descentralizado) minimalista, inspirado en Uniswap, para intercambiar dos tokens ERC‑20.

---

## 📦 Instalación y Despliegue (Remix)


1. **Desplegar**

   -Detalles en despliegue y pasos previos a la utilización del contrato:
     - En tiempo de despleigue se ingresaron las direcciones de los tokens:
       - `tokenA`: `0x7e285bee81b1349634e7Dc5924377a9aa984b812` (GMA)
       - `tokenB`: `0xEB6284d3d673517B6ad8a58E6fB7552E6B7637D2` (GMB)
     - Posteriormente a despliegue se aplicó approve en cada token en favor del contrato SimpleSwap.
      - Address de contrato SimpleSwap: `0x29E515B776653Dde3264D4AC1B4d1ab8b6a5338e`


---

## ⚙️ Funciones Principales

### 1. Constructor

```solidity
constructor(address _tokenA, address _tokenB)
```

**Descripción**: Inicializa el DEX indicando qué dos tokens gestionará.

- `_tokenA`: dirección del primer token (e.g., GMA).
- `_tokenB`: dirección del segundo token (e.g., GMB).

---

### 2. addLiquidity

```solidity
function addLiquidity(
  address _tokenA,
  address _tokenB,
  uint256 amountADesired,
  uint256 amountBDesired,
  uint256 amountAMin,
  uint256 amountBMin,
  address to,
  uint256 deadline
) external returns (uint256 amountA, uint256 amountB, uint256 liquidityMinted);
```

**Descripción**: Aporta tokens al pool y recibe a cambio **LP tokens** que representan tu participación.

- **Parámetros**:

  - `amountADesired`, `amountBDesired`: montos que deseas aportar.
  - `amountAMin`, `amountBMin`: montos mínimos aceptables (slippage).
  - `to`: dirección que recibirá los LP tokens.
  - `deadline`: límite de tiempo para la transacción.

- **Retorna**:

  - `amountA`, `amountB`: montos efectivos aportados (pueden ajustarse para mantener proporción).
  - `liquidityMinted`: **LP tokens** creados.

**Algoritmo**:

- Si el pool está vacío, usa directamente `amountADesired` y `amountBDesired`.
- Si ya hay reservas, calcula la proporción óptima usando `reserveA` y `reserveB`.
- Actualiza reservas y mint LP tokens con fórmula:
  - Primer proveedor: `sqrt(amountA * amountB)`.
  - Posteriores: `min((amountA * totalLiquidity)/reserveA, (amountB * totalLiquidity)/reserveB)`.

---

### 3. removeLiquidity

```solidity
function removeLiquidity(
  address _tokenA,
  address _tokenB,
  uint256 liquidityAmount,
  uint256 amountAMin,
  uint256 amountBMin,
  address to,
  uint256 deadline
) external returns (uint256 amountA, uint256 amountB);
```

**Descripción**: Quema tus LP tokens para retirar tu parte proporcional de `tokenA` y `tokenB`.

- **Parámetros**:

  - `liquidityAmount`: LP tokens a quemar.
  - `amountAMin`, `amountBMin`: montos mínimos que aceptas recibir.
  - `to`: dirección que recibirá los tokens.
  - `deadline`: límite de tiempo.

- **Retorna**:

  - `amountA`, `amountB`: cantidades de cada token que recibirás.

**Cálculo**:

```solidity
amountA = (liquidityAmount * reserveA) / totalLiquidity;
amountB = (liquidityAmount * reserveB) / totalLiquidity;
```

Reduce `liquidity` y `totalLiquidity` en consecuencia.

---

### 4. swapExactTokensForTokens

```solidity
function swapExactTokensForTokens(
  uint256 amountIn,
  uint256 amountOutMin,
  address[] calldata path,
  address to,
  uint256 deadline
) external;
```

**Descripción**: Intercambia un monto fijo de un token por al menos una cantidad mínima del segundo.

- **Parámetros**:
  - `amountIn`: cantidad exacta de input.
  - `amountOutMin`: mínimo de output que aceptas (slippage).
  - `path`: arreglo de dos direcciones `[tokenIn, tokenOut]`.
  - `to`: receptor del token de salida.
  - `deadline`: timestamp límite.

**Proceso**:

1. Verifica `path.length == 2` y validez de pares.
2. Transfiere `amountIn` al contrato.
3. Calcula salida con fórmula básica: `(amountIn * reserveOut) / (reserveIn + amountIn)`.
4. Verifica `amountOut >= amountOutMin`.
5. Envía `amountOut` al receptor y actualiza reservas.

---

## 📊 Consultas de Estado

- `reserveA()`, `reserveB()`: reserva actual de cada token.
- `liquidity(address)`: LP tokens en poder de una cuenta.
- `totalLiquidity()`: cantidad total de LP tokens emitidos.

---

## 📈 Funciones de Precio

```solidity
function getPrice(address _tokenA, address _tokenB) external view returns (uint256 price);
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut);
```

- **getPrice**: devuelve el precio de `tokenA` en términos de `tokenB`, escalado por `1e18`.
- **getAmountOut**: calcula la cantidad de tokens de salida según reservas y sin comisiones:
  ```solidity
  amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
  ```

---

## 🔄 LP Tokens

- **Minting**:
  - Primer proveedor recibe `sqrt(amountA * amountB)` LP tokens.
  - Posteriores reciben proporcionalmente según reservas.
- **Balance**: `liquidity[user]` almacena LP tokens de cada usuario.
- **Burning**: al remover liquidez, LP tokens se queman y el usuario recibe su parte de reservas.

---

## 📝 Ejemplo de Uso en Remix

```js
// Supongamos que 'simpleSwap' es la instancia desplegada
const user = accounts[0];
const tokenA = "0x7e285bee81b1349634e7Dc5924377a9aa984b812";
const tokenB = "0xEB6284d3d673517B6ad8a58E6fB7552E6B7637D2";

// 1. Aprobar tokens
await tokenAContract.methods.approve(simpleSwap.options.address, amountA).send({ from: user });
await tokenBContract.methods.approve(simpleSwap.options.address, amountB).send({ from: user });

// 2. Añadir liquidez
await simpleSwap.methods.addLiquidity(
  tokenA, tokenB,
  amountA, amountB,
  0, 0,
  user,
  Math.floor(Date.now() / 1000) + 60
).send({ from: user });

// 3. Swap
await simpleSwap.methods.swapExactTokensForTokens(
  swapAmount, 0,
  [tokenA, tokenB],
  user,
  Math.floor(Date.now() / 1000) + 60
).send({ from: user });

// 4. Quitar liquidez
await simpleSwap.methods.removeLiquidity(
  tokenA, tokenB,
  lpToBurn, 0, 0,
  user,
  Math.floor(Date.now() / 1000) + 60
).send({ from: user });
```

---

## 🔒 Consideraciones de Seguridad

- **Sin comisiones**: esta versión no implementa fees.
- **Swaps directos**: solo soporta pools de dos tokens.
- **Validaciones**: usa `require` para pares correctos, slippage y deadlines.
- **Inmutabilidad**: cualquier cambio de lógica requiere redeploy.

---

## 📄 Licencia

MIT License

