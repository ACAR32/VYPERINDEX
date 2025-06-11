# contracts/CurveIndex.vy

# --- Interfaces ---

interface ERC20:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def balanceOf(_owner: address) -> uint256: view
    def allowance(_owner: address, _spender: address) -> uint256: view
    def totalSupply() -> uint256: view

interface ConvexBooster:
    def deposit(_pid: uint256, _amount: uint256, _stake: bool) -> bool: nonpayable

interface ConvexRewardPool:
    def getReward(_account: address, _claimExtras: bool): nonpayable

# --- Contract Storage ---

owner: public(address)

# Core LP + staking data
lp_token: public(address)
booster: public(address)
convex_pool_id: public(uint256)
reward_contract: public(address)

# Emission tokens and lock routes
crv_token: public(address)
cvx_token: public(address)
crv_lock_receiver: public(address)
cvx_lock_receiver: public(address)

# Index token tracking
index_token_balance: HashMap[address, uint256]
total_supply: public(uint256)

# LP deposit tracking
lp_token_balances: HashMap[address, uint256]

# ETH Treasury
eth_treasury: public(uint256)

# --- Events ---

event Deposit:
    user: address
    amount: uint256

event ETHReceived:
    from_: address
    amount: uint256

event EmissionsHarvested:
    crv_amount: uint256
    cvx_amount: uint256

# --- Constructor ---

@external
def __init__(
    _lp_token: address,
    _booster: address,
    _pool_id: uint256,
    _reward_contract: address,
    _crv_token: address,
    _cvx_token: address,
    _crv_lock_receiver: address,
    _cvx_lock_receiver: address
):
    self.owner = msg.sender
    self.lp_token = _lp_token
    self.booster = _booster
    self.convex_pool_id = _pool_id
    self.reward_contract = _reward_contract
    self.crv_token = _crv_token
    self.cvx_token = _cvx_token
    self.crv_lock_receiver = _crv_lock_receiver
    self.cvx_lock_receiver = _cvx_lock_receiver
    self.eth_treasury = 0
    self.total_supply = 0

# --- ETH Deposit via Fallback ---

@payable
@external
def __default__():
    self.eth_treasury += msg.value
    log ETHReceived(msg.sender, msg.value)

# --- LP Deposit and Convex Stake ---

@external
def deposit_lp(amount: uint256):
    assert amount > 0, "Must deposit non-zero amount"

    # Transfer LPs to this contract
    success: bool = ERC20(self.lp_token).transferFrom(msg.sender, self, amount)
    assert success, "LP token transfer failed"

    # Approve booster
    ERC20(self.lp_token).transfer(self.booster, amount)

    # Stake into Convex Booster
    ok: bool = ConvexBooster(self.booster).deposit(self.convex_pool_id, am
