

## 合约框架：

`CarbonAllowanceManager.sol`：碳额度管理；

`CarbonAuctionTrade.sol`：拍卖形式的碳额度交易；

`CarbonMarketTrade.sol`：市场交易形式的碳额度交易；

`CarbonTrader.sol`：汇总两种交易机制；

`USDT.sol`：与碳额度交易的代币；

`CarbonPortal.sol`：与Vera相关的，通过该合约发放证明与鉴权;

<br>

## 合约已部署在Linea测试网：

USDT.sol：https://sepolia.lineascan.build/address/0xf0c75d5f53DeC8294101B474F77aEC13E444f6a3
<br> 

CarbonTrade主逻辑：https://sepolia.lineascan.build/address/0xe51afd3aacacfe2effc08913cf3c8c14ac188544
<br>

CarbonPortal.sol：https://sepolia.lineascan.build/address/0x0139E7BE68d904491f278d8221A76F09d7C450A2

<br>



## 部署：

### 1. 安装依赖

```
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
forge install Consensys/linea-attestation-registry --no-commit
```

<br>

### 2.测试

```
forge test -vvvv
```

<br>


### 3. 部署：

部署USDT

```
forge script --chain sepolia script/DeployUSDT.s.sol:DeployUSDT --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --verbose
```

部署CarbonTrade主逻辑：

```
forge script --chain sepolia script/DeployCarbonTrade.s.sol:DeployCarbonTrade --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --verbose
```

部署CarbonPortal：

```
forge script --chain sepolia script/DeployCarbonPortal.s.sol:DeployCarbonPortal --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --verbose
```

