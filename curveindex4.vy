# contracts/CurveIndex.vy

# --- Interfaces ---
interface ERC20:
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def balanceOf(_owner: address) -> uint256: view

interface CurveIndexGovernance:
    def isVotingPeriod() -> bool: view

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

# --- Set Governance Contract (One Time) ---

@external
def set_governance_contract(addr: address):
    assert msg.sender == self.owner
    assert self.governance_contract == empty(address)
    self.governance_contract = addr

# --- Admin: Add LP Token to Index (Called by Governance) ---

@external
def addLPToken(lp_token: address):
    assert msg.sender == self.governance_contract
    self.lp_tokens[self.lp_token_count] = lp_token
    self.lp_token_count += 1

# --- Deposit LP Token into Index ---

@external
def deposit_lp(lp_token: address, amount: uint256):
    assert amount > 0, "Zero deposit"
    found: bool = False
    for i in range(10):
        if self.lp_tokens[i] == lp_token:
            found = True
            break
    assert found, "LP not supported"

    success: bool = ERC20(lp_token).transferFrom(msg.sender, self, amount)
    assert success, "Transfer failed"

    self.lp_token_balances[lp_token] += amount
    self.lp_token_user_balances[msg.sender][lp_token] += amount
    self.index_token_balance[msg.sender] += amount
    self.total_supply += amount

    log Deposit(msg.sender, lp_token, amount)

# --- Redeem crvINDEX for Underlying LPs (During Voting Period Only) ---

@external
def redeem(amount: uint256):
    assert amount > 0, "Nothing to redeem"
    assert amount <= self.index_token_balance[msg.sender], "Too much"

    assert CurveIndexGovernance(self.governance_contract).isVotingPeriod(), "Not during voting"

    share: decimal = convert(amount, decimal) / convert(self.total_supply, decimal)

    self.index_token_balance[msg.sender] -= amount
    self.total_supply -= amount

    for i in range(self.lp_token_count):
        token: address = self.lp_tokens[i]
        total_token_balance: uint256 = self.lp_token_balances[token]
        payout: uint256 = floor(share * convert(total_token_balance, decimal))

        fee: uint256 = payout * WITHDRAW_FEE_BPS / 10_000
        user_amount: uint256 = payout - fee

        self.lp_token_balances[token] -= payout
        ERC20(token).transfer(msg.sender, user_amount)

    log Redeemed(msg.sender, amount, WITHDRAW_FEE_BPS)

# --- View Functions ---

@view
@external
def get_user_index_balance(user: address) -> uint256:
    return self.index_token_balance[user]

@view
@external
def get_user_lp_balance(user: address, token: address) -> uint256:
    return self.lp_token_user_balances[user][token]

@view
@external
def get_total_eth() -> uint256:
    return self.eth_treasury
