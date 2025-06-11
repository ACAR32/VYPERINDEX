# contracts/CurveIndex.vy

# Vyper contract for Curve LP index aggregation and ETH treasury growth

# --- Storage Variables ---

owner: public(address)
eth_treasury: public(uint256)
total_supply: public(uint256)  # Total index token supply
lp_token_balances: HashMap[address, uint256]  # Individual LP token deposits (for now, single token)
index_token_balance: HashMap[address, uint256]

# --- Events ---

event Deposit:
    user: address
    amount: uint256

event ETHReceived:
    from_: address
    amount: uint256

# --- Constructor ---

@external
def __init__():
    self.owner = msg.sender
    self.eth_treasury = 0
    self.total_supply = 0

# --- Deposit ETH into treasury (via fallback) ---

@payable
@external
def __default__():
    self.eth_treasury += msg.value
    log ETHReceived(msg.sender, msg.value)

# --- Simulated LP Deposit ---

@external
def deposit_lp(amount: uint256):
    """
    @notice Simulate deposit of Curve LP token (placeholder — integration TBD)
    """
    assert amount > 0, "Amount must be greater than 0"
    self.lp_token_balances[msg.sender] += amount
    self.index_token_balance[msg.sender] += amount  # For now, 1:1 mint
    self.total_supply += amount

    log Deposit(msg.sender, amount)

# --- View balances ---

@view
@external
def get_user_index_balance(user: address) -> uint256:
    return self.index_token_balance[user]

@view
@external
def get_total_eth() -> uint256:
    return self.eth_treasury
