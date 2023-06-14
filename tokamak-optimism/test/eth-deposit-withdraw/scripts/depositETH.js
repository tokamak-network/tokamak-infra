import process from "process";
import dotenv from "dotenv";
import { ethers } from "ethers";
import { predeploys } from "@eth-optimism/contracts";

import l1StandardBridgeArtifact from "@eth-optimism/contracts/artifacts/contracts/L1/messaging/L1StandardBridge.sol/L1StandardBridge.json" assert { type: 'json' }
import l2StandardBridgeArtifact from "@eth-optimism/contracts/artifacts/contracts/L2/messaging/L2StandardBridge.sol/L2StandardBridge.json" assert { type: 'json' }

dotenv.config()

const l1Url = process.env.L1_URL || 'http://localhost:9545'
const l2Url = process.env.L2_URL || 'http://localhost:8545'
const balance = process.env.TEST_BALANCE || '0.01'
const key =
  process.env.PRIVATE_KEY ||
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'

const factory__L1StandardBridge = new ethers.ContractFactory(
  l1StandardBridgeArtifact.abi,
  l1StandardBridgeArtifact.bytecode
)
const factory__L2StandardBridge = new ethers.ContractFactory(
  l2StandardBridgeArtifact.abi,
  l2StandardBridgeArtifact.bytecode
)

const main = async () => {
  const l1RpcProvider = new ethers.providers.JsonRpcProvider(l1Url)
  const l2RpcProvider = new ethers.providers.JsonRpcProvider(l2Url)

  const l1Wallet = new ethers.Wallet(key, l1RpcProvider)
  const l2Wallet = new ethers.Wallet(key, l2RpcProvider)

  const getBalances = async () => {
    const l1Eth = ethers.utils.formatEther(
      await l1RpcProvider.getBalance(l1Wallet.address)
    )
    const l2Eth = ethers.utils.formatEther(
      await l2RpcProvider.getBalance(l2Wallet.address)
    )

    return [l1Eth, l2Eth]
  }

  const L2StandardBridge = factory__L2StandardBridge
    .connect(l2Wallet)
    .attach(predeploys.L2StandardBridge)
  const L1StandardBridgeAddress = await L2StandardBridge.l1TokenBridge()
  const L1StandardBridge = factory__L1StandardBridge
    .connect(l1Wallet)
    .attach(L1StandardBridgeAddress)

  console.log(`L1Url: ${l1Url}`)
  console.log(`L2Url: ${l2Url}`)
  console.log(`L1StandardBridgeAddress: ${L1StandardBridgeAddress}`)
  console.log(`---------------- Deposit ${balance} ----------------`)
  const balancesB4 = await getBalances()
  const tx = await L1StandardBridge.depositETH(
    200000, // Gas for L2 transaction
    [],
    {
      value: ethers.utils.parseEther(balance),
    }
  )
  console.log(`TX Hash: ${tx.hash}`)

  const receipt = await tx.wait()
  if (receipt.status !== 1) {
    throw(new Error('transaction is failed'));
  }

  let balancesNow = await getBalances()
  console.log(
    `Before\tL1:${balancesB4[0]}\tL2:${balancesB4[1]}`)
  console.log(
    `After\tL1:${balancesNow[0]}\tL2:${balancesNow[1]}`)

  let seconds = 0
  // eslint-disable-next-line no-constant-condition
  while (true) {
    await new Promise((resolve) => setTimeout(resolve, 1000))
    seconds++
    balancesNow = await getBalances()
    if (balancesNow[1] === balancesB4[1]) {
      process.stdout.write(".");
    } else {
      console.log(
        `\nAfter ${seconds} second${seconds - 1 ? 's' : ''} \tL1:${
          balancesNow[0]
        }\tL2:${balancesNow[1]}`)
      break;
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
