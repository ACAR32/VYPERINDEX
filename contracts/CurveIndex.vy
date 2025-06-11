# contracts/CurveIndex.vy

# --- Interfaces ---
interface ERC20:
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def balanceOf(_owner: address) -> uint256: view
    def allowance(_owner: address, _spender: address) -> uint256: view
    def totalSupply() -> uint256: view

# --- Contract Storage ---

owner: public(address)
eth_treasury: public(uint256)
total_supply: public(uint256)
index_token_balance: HashMap[address, uint256]

lp_token: public(address)
lp_token_balances: HashMap[address, uint256]

# --- Events ---

event Deposit:
    user: address
    amount: uint256

event ETHReceived:
    from_: address
    amount: uint256

# --- Constructor ---

@external
def __init__(_lp_token: address):
    self.owner = msg.sender
    self.lp_token = _lp_token
    self.eth_treasury = 0
    self.total_supply = 0

# --- Fallback to Accept ETH ---

@payable
@external
def __default__():
    self.eth_treasury += msg.value
    log ETHReceived(msg.sender, msg.value)

# --- Real LP Deposit Function ---

@external
def deposit_lp(amount: uint256):
    assert amount > 0, "Must deposit non-zero amount"

    # Transfer LP tokens from user to contract
    success: bool = ERC20(self.lp_token).transferFrom(msg.sender, self, amount)
    assert success, "LP token transfer failed"

    # Track balances
    self.lp_token_balances[msg.sender] += amount
    self.index_token_balance[msg.sender] += amount  # 1:1 mint for now
    self.total_supply += amount

    log Deposit(msg.sender, amount)

# --- View Functions ---

@view
@external
def get_user_index_balance(user: address) -> uint256:
    return self.index_token_balance[user]

@view
@external
def get_user_lp_balance(user: address) -> uint256:
    return self.lp_token_balances[user]

@view
@external
def get_total_eth() -> uint256:
    return self.eth_treasury
