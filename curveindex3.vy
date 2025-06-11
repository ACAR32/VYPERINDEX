# contracts/CurveIndex.vy

# --- Interfaces ---

interface ERC20:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def balanceOf(_owner: address) -> uint256: view
    def approve(_spender: address, _value: uint256) -> bool: nonpayable

interface CurveMinter:
    def mint(_gauge: address): nonpayable

interface veCRV:
    def increase_amount(_value: uint256): nonpayable
    def create_lock(_value: uint256, _unlock_time: uint256): nonpayable
    def locked(__addr: address) -> (uint256, uint256): view

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
gauge: public(address)
crv_token: public(address)
curve_minter: public(address)
vecrv_contract: public(address)

eth_treasury: public(uint256)
lp_token_balances: HashMap[address, uint256]

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

event CRVHarvested:
    crv_amount: uint256

# --- Constructor ---

@external
def __init__(
    _lp_token: address,
    _gauge: address,
    _crv_token: address,
    _curve_minter: address,
    _vecrv_contract: address
):
    self.name = "Curve LP Index Token"
    self.symbol = "crvINDEX"
    self.decimals = 18

    self.lp_token = _lp_token
    self.gauge = _gauge
    self.crv_token = _crv_token
    self.curve_minter = _curve_minter
    self.vecrv_contract = _vecrv_contract

# --- Accept ETH (donations or treasury inflow) ---

@payable
@external
def __default__():
    self.eth_treasury += msg.value
    log ETHReceived(msg.sender, msg.value)

# --- Deposit LP and Mint Index Token ---

@external
def deposit_lp(amount: uint256):
    assert amount > 0, "Cannot deposit zero"

    success: bool = ERC20(self.lp_token).transferFrom(msg.sender, self, amount)
    assert success, "LP transfer failed"

    # Optional: stake in gauge here with separate call

    self.balanceOf[msg.sender] += amount
    self.total_supply += amount
    self.lp_token_balances[msg.sender] += amount

    log Transfer(ZERO_ADDRESS, msg.sender, amount)
    log Deposit(msg.sender, amount)

# --- Public Harvest + Auto-Lock CRV ---

@external
def harvest():
    # Mint CRV from Curve gauge
    CurveMinter(self.curve_minter).mint(self.gauge)

    crv_balance: uint256 = ERC20(self.crv_token).balanceOf(self)
    if crv_balance > 0:
        # Approve and lock in veCRV
        ERC20(self.crv_token).approve(self.vecrv_contract, crv_balance)
        veCRV(self.vecrv_contract).increase_amount(crv_balance)
        log CRVHarvested(crv_balance)

# --- ERC-20 Transfer Logic ---

@external
def transfer(_to: address, _value: uint256) -> bool:
    assert self.balanceOf[msg.sender] >= _value, "Insufficient balance"
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value
    log Transfer(msg.sender, _to, _value)
    return True

@external
def approve(_spender: address, _value: uint256) -> bool:
    self.allowances[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    allowed: uint256 = self.allowances[_from][msg.sender]
    assert allowed >= _value, "Insufficient allowance"
    assert self.balanceOf[_from] >= _value, "Insufficient balance"
    self.allowances[_from][msg.sender] = allowed - _value
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    log Transfer(_from, _to, _value)
    return True

@view
@external
def allowance(_owner: address, _spender: address) -> uint256:
    return self.allowances[_owner][_spender]
