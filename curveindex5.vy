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
    def add_liquidity(amounts: uint256[2], min_mint: uint256) -> uint256: nonpayable

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

# Constants for zap
usdc: public(address)
eth_to_usdc_pool: public(address)  # Curve pool for ETH → USDC
usdc_to_lp_pool: public(HashMap[address, address])  # LP token => Curve pool for USDC → LP

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
    fee_bps: uint256

# --- Constructor ---

@external
def __init__():
    self.owner = msg.sender
    self.eth_treasury = 0
    self.total_supply = 0

# --- Fallback to Accept ETH ---

@payable
@external
def __default__():
    self.eth_treasury += msg.value
    log ETHReceived(msg.sender, msg.value)

# --- Admin Functions ---

@external
def set_governance_contract(addr: address):
    assert msg.sender == self.owner
    assert self.governance_contract == empty(address)
    self.governance_contract = addr

@external
def set_usdc_token(_usdc: address):
    assert msg.sender == self.owner
    self.usdc = _usdc

@external
def set_eth_to_usdc_pool(pool: address):
    assert msg.sender == self.owner
    self.eth_to_usdc_pool = pool

@external
def set_usdc_to_lp_pool(lp: address, pool: address):
    assert msg.sender == self.owner
    self.usdc_to_lp_pool[lp] = pool

@external
def addLPToken(lp_token: address):
    assert msg.sender == self.governance_contract
    for i in range(self.lp_token_count):
        assert self.lp_tokens[i] != lp_token, "Duplicate LP"
    self.lp_tokens[self.lp_token_count] = lp_token
    self.lp_token_count += 1

# --- Deposit LP Token ---

@external
def deposit_lp(lp_token: address, amount: uint256):
    assert amount > 0, "Zero deposit"
    found: bool = False
    for i in range(10):
        if self.lp_tokens[i] == lp_token:
            found = True
            break
    assert found, "LP not supported"

    success: bool = ERC20(lp_token).t_
