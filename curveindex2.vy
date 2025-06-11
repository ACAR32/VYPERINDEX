# contracts/CurveIndex.vy

# --- Interfaces ---

interface ERC20:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def balanceOf(_owner: address) -> uint256: view

interface ConvexBooster:
    def deposit(_pid: uint256, _amount: uint256, _stake: bool) -> bool: nonpayable

interface ConvexRewardPool:
    def getReward(_account: address, _claimExtras: bool): nonpayable

# --- ERC-20 Metadata ---

name: public(String[64])
symbol: public(String[32])
decimals: public(uint256)

# --- ERC-20 Storage ---

total_supply: public(uint256)
balanceOf: public(HashMap[address, uint256])
allowances: HashMap[address, HashMap[address, uint256]]

# --- Protocol Storage ---

lp_token: public(address)
booster: public(address)
convex_pool_id: public(uint256)
reward_contract: public(address)
crv_token: public(address)
cvx_token: public(address)
crv_lock_receiver: public(address)
cvx_lock_receiver: public(address)

lp_token_balances: HashMap[address, uint256]
eth_treasury: public(uint256)

# --- Events ---

event Transfer:
    sender: address
    receiver: address
    value: uint256

event Approval:
    owner: address
    spender: address
    value: uint256

event Deposit:
    user: address
    amount: uint256

event ETHReceived:
    from_: address
    amount: uint256

event EmissionsHarvested:
    crv_amount: uint256
    cvx_amount: uint256

# --- Constructor (Immutable Setup) ---

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
    self.name = "Curve LP Index Token"
    self.symbol = "crvINDEX"
    self.decimals = 18

    self.lp_token = _lp_token
    self.booster = _booster
    self.convex_pool_id = _pool_id
    self.reward_contract = _reward_contract
    self.crv_token = _crv_token
    self.cvx_token = _cvx_token
    self.crv_lock_receiver = _crv_lock_receiver
    self.cvx_lock_receiver = _cvx_lock_receiver

# --- ETH Deposit ---

@payable
@external
def __default__():
    self.eth_treasury += msg.value
    log ETHReceived(msg.sender, msg.value)

# --- Deposit Curve LP and Stake in Convex ---

@external
def deposit_lp(amount: uint256):
    assert amount > 0, "Zero deposit not allowed"

    success: bool = ERC20(self.lp_token).transferFrom(msg.sender, self, amount)
    assert success, "TransferFrom failed"

    ERC20(self.lp_token).transfer(self.booster, amount)
    ok: bool = ConvexBooster(self.booster).deposit(self.convex_pool_id, amount, True)
    assert ok, "Convex deposit failed"

    self.balanceOf[msg.sender] += amount
    self.total_supply += amount
    self.lp_token_balances[msg.sender] += amount

    log Transfer(ZERO_ADDRESS, msg.sender, amount)
    log Deposit(msg.sender, amount)

# --- Public Harvest: Forward CRV & CVX to Lockers ---

@external
def harvest():
    ConvexRewardPool(self.reward_contract).getReward(self, True)

    crv_amount: uint256 = ERC20(self.crv_token).balanceOf(self)
    if crv_amount > 0:
        ERC20(self.crv_token).transfer(self.crv_lock_receiver, crv_amount)

    cvx_amount: uint256 = ERC20(self.cvx_token).balanceOf(self)
