#[starknet::interface]
pub trait ISaccoSimple<TContractState> {
    fn create_sacco(ref self: TContractState, name: ByteArray, max_members: u8, contribution_amount: u256);
    fn join_sacco(ref self: TContractState, sacco_id: u256);
    fn make_contribution(ref self: TContractState, sacco_id: u256, amount: u256);
    fn get_sacco_info(self: @TContractState, sacco_id: u256) -> SaccoInfo;
    fn get_total_saccos(self: @TContractState) -> u256;
    fn is_member(self: @TContractState, sacco_id: u256, member: starknet::ContractAddress) -> bool;
    fn get_balance(self: @TContractState, sacco_id: u256) -> u256;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SaccoInfo {
    pub id: u256,
    pub name: ByteArray,
    pub creator: starknet::ContractAddress,
    pub max_members: u8,
    pub contribution_amount: u256,
    pub total_balance: u256,
    pub member_count: u8,
    pub is_active: bool,
    pub created_at: u64,
}

#[starknet::contract]
pub mod SaccoSimple {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use super::{ISaccoSimple, SaccoInfo};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Using STRK as placeholder for USDC
    pub const TOKEN_CONTRACT: felt252 = 
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        SaccoCreated: SaccoCreated,
        MemberJoined: MemberJoined,
        ContributionMade: ContributionMade,
    }

    #[derive(Drop, starknet::Event)]
    struct SaccoCreated {
        #[key]
        sacco_id: u256,
        name: ByteArray,
        creator: ContractAddress,
        max_members: u8,
        contribution_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberJoined {
        #[key]
        sacco_id: u256,
        member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionMade {
        #[key]
        sacco_id: u256,
        member: ContractAddress,
        amount: u256,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        
        // SACCO management
        total_saccos: u256,
        saccos: Map<u256, SaccoInfo>,
        
        // Member management
        members: Map<(u256, ContractAddress), bool>,
        member_contributions: Map<(u256, ContractAddress), u256>,
        
        // Balance tracking
        sacco_balances: Map<u256, u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.total_saccos.write(0);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl SaccoSimpleImpl of ISaccoSimple<ContractState> {
        fn create_sacco(ref self: ContractState, name: ByteArray, max_members: u8, contribution_amount: u256) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let sacco_id = self.total_saccos.read() + 1;
            
            // Validate parameters
            if max_members == 0 { panic!() };
            if contribution_amount == 0 { panic!() };
            
            let sacco_info = SaccoInfo {
                id: sacco_id,
                name: name.clone(),
                creator: caller,
                max_members,
                contribution_amount,
                total_balance: 0,
                member_count: 0,
                is_active: true,
                created_at: current_time,
            };
            
            self.saccos.write(sacco_id, sacco_info);
            self.total_saccos.write(sacco_id);
            self.sacco_balances.write(sacco_id, 0);
            
            self.emit(SaccoCreated {
                sacco_id,
                name,
                creator: caller,
                max_members,
                contribution_amount,
            });
        }

        fn join_sacco(ref self: ContractState, sacco_id: u256) {
            let caller = get_caller_address();
            
            // Check if SACCO exists and is active
            let mut sacco_info = self.saccos.read(sacco_id);
            if !sacco_info.is_active { panic!() };
            
            // Check if caller is already a member
            if self.members.read((sacco_id, caller)) { panic!() };
            
            // Check if SACCO has space
            if sacco_info.member_count >= sacco_info.max_members { panic!() };
            
            self.members.write((sacco_id, caller), true);
            self.member_contributions.write((sacco_id, caller), 0);
            
            // Update member count
            sacco_info.member_count += 1;
            self.saccos.write(sacco_id, sacco_info);
            
            self.emit(MemberJoined { sacco_id, member: caller });
        }

        fn make_contribution(ref self: ContractState, sacco_id: u256, amount: u256) {
            let caller = get_caller_address();
            
            // Check if caller is a member
            if !self.members.read((sacco_id, caller)) { panic!() };
            
            // Check if SACCO is active
            let mut sacco_info = self.saccos.read(sacco_id);
            if !sacco_info.is_active { panic!() };
            
            // Validate contribution amount
            if amount < sacco_info.contribution_amount { panic!() };
            
            // Transfer tokens from member to contract
            let token_contract_address: ContractAddress = TOKEN_CONTRACT.try_into().unwrap();
            let token_dispatcher = IERC20Dispatcher { contract_address: token_contract_address };
            
            token_dispatcher.transfer_from(caller, get_contract_address(), amount);
            
            // Update member contribution record
            let member_contribution = self.member_contributions.read((sacco_id, caller));
            self.member_contributions.write((sacco_id, caller), member_contribution + amount);
            
            // Update SACCO balance
            let current_balance = self.sacco_balances.read(sacco_id);
            self.sacco_balances.write(sacco_id, current_balance + amount);
            
            // Update SACCO info
            sacco_info.total_balance += amount;
            self.saccos.write(sacco_id, sacco_info);
            
            self.emit(ContributionMade {
                sacco_id,
                member: caller,
                amount,
            });
        }

        fn get_sacco_info(self: @ContractState, sacco_id: u256) -> SaccoInfo {
            self.saccos.read(sacco_id)
        }

        fn get_total_saccos(self: @ContractState) -> u256 {
            self.total_saccos.read()
        }

        fn is_member(self: @ContractState, sacco_id: u256, member: ContractAddress) -> bool {
            self.members.read((sacco_id, member))
        }

        fn get_balance(self: @ContractState, sacco_id: u256) -> u256 {
            self.sacco_balances.read(sacco_id)
        }
    }
}