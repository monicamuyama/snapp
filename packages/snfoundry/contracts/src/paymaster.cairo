#[starknet::contract]
pub mod Paymaster {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{get_caller_address, get_contract_address, ContractAddress};
    use starknet::Uint256 as u256;
    use core::option::Option;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // mapping token_address => deposited balance (Uint256)
        deposits: Map<ContractAddress, u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        // deposits mapping initialized empty
    }

    // deposit ERC20 token into paymaster (caller must approve this contract)
    fn deposit_token(ref self: ContractState, token: ContractAddress, amount: u256) {
        let caller = get_caller_address();
        assert(!(amount.low == 0 && amount.high == 0), 'Amount must be > 0');

        let dispatcher = IERC20Dispatcher { contract_address: token };
        // transfer_from caller -> this contract
        dispatcher.transfer_from(caller, get_contract_address(), amount);

        let prev = self.deposits.read(token);
        let new = u256_add(prev, amount);
        self.deposits.write(token, new);
    }

    // withdraw funds (owner only)
    fn withdraw_token(ref self: ContractState, token: ContractAddress, to: ContractAddress, amount: u256) {
        let caller = get_caller_address();
        // only owner can withdraw
        assert(self.ownable.is_owner(caller), 'Only owner');
        let prev = self.deposits.read(token);
        assert(!u256_lt(prev, amount), 'Insufficient balance');

        let new = u256_sub(prev, amount);
        self.deposits.write(token, new);

        let dispatcher = IERC20Dispatcher { contract_address: token };
        dispatcher.transfer(to, amount);
    }

    // Placeholder: sponsor a transaction by deducting fee_amount from deposited token.
    // In production this must validate tx metadata and tie into account abstraction.
    fn sponsor_tx(ref self: ContractState, token: ContractAddress, fee_amount: u256) -> bool {
        let prev = self.deposits.read(token);
        if u256_lt(prev, fee_amount) {
            return false;
        }
        let new = u256_sub(prev, fee_amount);
        self.deposits.write(token, new);
        true
    }

    // --- small u256 helpers (replace with your project's standard utils) ---
    fn u256_add(a: u256, b: u256) -> u256 {
        let low = a.low + b.low;
        let mut carry = 0;
        if low < a.low {
            carry = 1;
        }
        let high = a.high + b.high + carry;
        u256 { low, high }
    }

    fn u256_sub(a: u256, b: u256) -> u256 {
        let mut borrow = 0;
        let low = if a.low < b.low {
            borrow = 1;
            a.low - b.low
        } else {
            a.low - b.low
        };
        let high = a.high - b.high - borrow;
        u256 { low, high }
    }

    fn u256_lt(a: u256, b: u256) -> bool {
        if a.high < b.high {
            return true;
        }
        if a.high > b.high {
            return false;
        }
        a.low < b.low
    }
}
