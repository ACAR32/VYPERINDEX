# contracts/CurveIndex.vy

# --- Interfaces ---
interface ERC20:
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def balanceOf(_owner: address) -> uint256: view

interface CurveIndexGovernance:
    def isVotingPeriod() -> bool: view

interface CurvePool:
    def exchange(i: int128, j: int128, dx: uint256, min_dy: uint256) -> uint256: nonpayable

# --- Storage ---

owner: public(address)
eth_treasury: public(uint256)
total_supply: public(uint256)

index_token_balance: HashMap[address, uint256]

lp_tokens: public(address[10])  # up to 10 LP tokens in the index
lp_token_count: public(uint256)
lp_token_balances: HashMap[address, uint256]  # token => total held

lp_token_user_balances: HashMap[address, HashMap[address, uint256]]

governance_contract: public(address)

WITHDRAW_FEE_BPS: constant(uint256) = 25  # 0.25%

# Zap-related config
usdc: public(address)
eth_to_usdc_pool: public(address)
usdc_to_lp_pool: public(HashMap[address, address])

# Redemption config
crvUSD: public(address)
lp_to_crvusd_pool: public(HashMap[address, address])

# --- Events ---

event Deposit:
    user: address
    lp_token: address
    amount: uint256

event ETHReceived:
    from_: address
    amount: uint256

event Redeemed:
    user: address
    index_burned: uint256
