#[starknet::interface]
pub trait ISaccoCore<TContractState> {
    // SACCO Group Management
    fn create_sacco_group(
        ref self: TContractState,
        group_name: ByteArray,
        max_members: u8,
        contribution_amount: u256,
        contribution_frequency: u8, // days
        admin_address: ContractAddress
    );
    fn get_sacco_info(self: @TContractState, group_id: u256) -> SaccoInfo;
    fn get_total_groups(self: @TContractState) -> u256;
    
    // Member Management
    fn join_sacco(ref self: TContractState, group_id: u256);
    fn leave_sacco(ref self: TContractState, group_id: u256);
    fn invite_member(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn get_member_count(self: @TContractState, group_id: u256) -> u8;
    fn is_member(self: @TContractState, group_id: u256, member_address: ContractAddress) -> bool;
    
    // Contribution Management
    fn make_contribution(ref self: TContractState, group_id: u256, amount: u256);
    fn get_contribution_balance(self: @TContractState, group_id: u256) -> u256;
    fn get_member_contribution(self: @TContractState, group_id: u256, member_address: ContractAddress) -> u256;
    
    // Rotation and Payout Management
    fn start_rotation_cycle(ref self: TContractState, group_id: u256);
    fn process_payout(ref self: TContractState, group_id: u256, recipient_address: ContractAddress);
    fn get_current_cycle(self: @TContractState, group_id: u256) -> u8;
    fn get_next_payout_recipient(self: @TContractState, group_id: u256) -> ContractAddress;
    
    // Emergency Functions
    fn emergency_withdraw(ref self: TContractState, group_id: u256);
    fn pause_sacco(ref self: TContractState, group_id: u256);
    fn resume_sacco(ref self: TContractState, group_id: u256);
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SaccoInfo {
    pub group_id: u256,
    pub group_name: ByteArray,
    pub admin_address: ContractAddress,
    pub max_members: u8,
    pub contribution_amount: u256,
    pub contribution_frequency: u8,
    pub total_contributions: u256,
    pub current_cycle: u8,
    pub is_active: bool,
    pub is_paused: bool,
    pub created_at: u64,
    pub last_contribution_at: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct MemberInfo {
    pub member_address: ContractAddress,
    pub joined_at: u64,
    pub total_contributed: u256,
    pub has_received_payout: bool,
    pub payout_cycle: Option<u8>,
    pub is_active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ContributionRecord {
    pub member_address: ContractAddress,
    pub amount: u256,
    pub cycle: u8,
    pub timestamp: u64,
}

#[starknet::contract]
pub mod SaccoCore {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, get_block_timestamp
        // contract_address_const // removed: unused import
        ,
    };

    // Add a clear alias so the rest of the file can continue using `u256`
    // while mapping to the standard Uint256 type exposed by the Starknet Cairo library.
    // This helps avoid confusion between tooling that expects `Uint256` vs `u256`.
    use starknet::Uint256 as u256;

    use super::{ISaccoCore, SaccoInfo, MemberInfo, ContributionRecord};
    use core::option::OptionTrait;
    use core::option::Option;
    use core::array::ArrayTrait;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // USDC contract address (using STRK as placeholder for now)
    pub const USDC_CONTRACT: felt252 = 
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        SaccoCreated: SaccoCreated,
        MemberJoined: MemberJoined,
        MemberLeft: MemberLeft,
        ContributionMade: ContributionMade,
        PayoutProcessed: PayoutProcessed,
        RotationCycleStarted: RotationCycleStarted,
        EmergencyWithdraw: EmergencyWithdraw,
        SaccoPaused: SaccoPaused,
        SaccoResumed: SaccoResumed,
    }

    #[derive(Drop, starknet::Event)]
    struct SaccoCreated {
        #[key]
        group_id: u256,
        group_name: ByteArray,
        admin_address: ContractAddress,
        max_members: u8,
        contribution_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberJoined {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberLeft {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionMade {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        amount: u256,
        cycle: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct PayoutProcessed {
        #[key]
        group_id: u256,
        recipient_address: ContractAddress,
        amount: u256,
        cycle: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct RotationCycleStarted {
        #[key]
        group_id: u256,
        new_cycle: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyWithdraw {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct SaccoPaused {
        #[key]
        group_id: u256,
        paused_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct SaccoResumed {
        #[key]
        group_id: u256,
        resumed_by: ContractAddress,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        
        // SACCO Groups
        total_groups: u256,
        sacco_groups: Map<u256, SaccoInfo>,
        
        // Members
        sacco_members: Map<(u256, ContractAddress), MemberInfo>,
        member_count: Map<u256, u8>,
        
        // Contributions
        contribution_records: Map<(u256, ContractAddress, u8), ContributionRecord>,
        total_contributions: Map<u256, u256>,
        
        // Rotation Management
        payout_order: Map<u256, Array<ContractAddress>>,
        current_payout_index: Map<u256, u8>,
        
        // Access Control
        is_admin: Map<(u256, ContractAddress), bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.total_groups.write(0);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl SaccoCoreImpl of ISaccoCore<ContractState> {
        fn create_sacco_group(
            ref self: ContractState,
            group_name: ByteArray,
            max_members: u8,
            contribution_amount: u256,
            contribution_frequency: u8,
            admin_address: ContractAddress
        ) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let group_id = self.total_groups.read() + 1;
            
            // Validate parameters
            assert(max_members > 0, 'Max members must be greater than 0');
            assert(contribution_amount > 0, 'Contribution amount must be greater than 0');
            assert(contribution_frequency > 0, 'Contribution frequency must be greater than 0');
            
            let sacco_info = SaccoInfo {
                group_id,
                group_name: group_name.clone(),
                admin_address,
                max_members,
                contribution_amount,
                contribution_frequency,
                total_contributions: 0,
                current_cycle: 0,
                is_active: true,
                is_paused: false,
                created_at: current_time,
                last_contribution_at: 0,
            };
            
            self.sacco_groups.write(group_id, sacco_info);
            self.total_groups.write(group_id);
            self.is_admin.write((group_id, admin_address), true);
            
            self.emit(SaccoCreated {
                group_id,
                group_name,
                admin_address,
                max_members,
                contribution_amount,
            });
        }

        fn get_sacco_info(self: @ContractState, group_id: u256) -> SaccoInfo {
            self.sacco_groups.read(group_id)
        }

        fn get_total_groups(self: @ContractState) -> u256 {
            self.total_groups.read()
        }

        fn join_sacco(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check if SACCO exists and is active
            let sacco_info = self.sacco_groups.read(group_id);
            assert(sacco_info.is_active, 'SACCO is not active');
            assert(!sacco_info.is_paused, 'SACCO is paused');
            
            // Check if caller is already a member
            assert(!self.is_member(group_id, caller), 'Already a member of this SACCO');
            
            // Check if SACCO has space
            let current_members = self.member_count.read(group_id);
            assert(current_members < sacco_info.max_members, 'SACCO is full');
            
            let member_info = MemberInfo {
                member_address: caller,
                joined_at: current_time,
                total_contributed: 0,
                has_received_payout: false,
                payout_cycle: Option::None,
                is_active: true,
            };
            
            self.sacco_members.write((group_id, caller), member_info);
            self.member_count.write(group_id, current_members + 1);
            
            self.emit(MemberJoined { group_id, member_address: caller });
        }

        fn leave_sacco(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Check if caller is a member
            assert(self.is_member(group_id, caller), 'Not a member of this SACCO');
            
            // Check if SACCO is paused
            let sacco_info = self.sacco_groups.read(group_id);
            assert(!sacco_info.is_paused, 'SACCO is paused');
            
            let member_info = self.sacco_members.read((group_id, caller));
            assert(member_info.is_active, 'Member is not active');
            
            // Update member status
            let mut updated_member = member_info;
            updated_member.is_active = false;
            self.sacco_members.write((group_id, caller), updated_member);
            
            let current_members = self.member_count.read(group_id);
            self.member_count.write(group_id, current_members - 1);
            
            self.emit(MemberLeft { group_id, member_address: caller });
        }

        fn invite_member(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can invite members
            assert(self.is_admin.read((group_id, caller)), 'Only admin can invite members');
            
            // Check if SACCO exists and is active
            let sacco_info = self.sacco_groups.read(group_id);
            assert(sacco_info.is_active, 'SACCO is not active');
            
            // For now, just emit an event. In a real implementation, 
            // this would trigger an off-chain invitation system
            self.emit(MemberJoined { group_id, member_address });
        }

        fn get_member_count(self: @ContractState, group_id: u256) -> u8 {
            self.member_count.read(group_id)
        }

        fn is_member(self: @ContractState, group_id: u256, member_address: ContractAddress) -> bool {
            let member_info = self.sacco_members.read((group_id, member_address));
            member_info.is_active
        }

        fn make_contribution(ref self: ContractState, group_id: u256, amount: u256) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Check if caller is a member
            assert(self.is_member(group_id, caller), 'Not a member of this SACCO');
            
            // Check if SACCO is active and not paused
            let mut sacco_info = self.sacco_groups.read(group_id);
            assert(sacco_info.is_active, 'SACCO is not active');
            assert(!sacco_info.is_paused, 'SACCO is paused');
            
            // Validate contribution amount
            assert(amount >= sacco_info.contribution_amount, 'Contribution amount too low');
            
            // Transfer USDC tokens from member to contract
            let usdc_contract_address: ContractAddress = USDC_CONTRACT.try_into().unwrap();
            let usdc_dispatcher = IERC20Dispatcher { contract_address: usdc_contract_address };
            
            usdc_dispatcher.transfer_from(caller, get_contract_address(), amount);
            
            // Update member contribution record
            let mut member_info = self.sacco_members.read((group_id, caller));
            member_info.total_contributed += amount;
            self.sacco_members.write((group_id, caller), member_info);
            
            // Create contribution record
            let contribution_record = ContributionRecord {
                member_address: caller,
                amount,
                cycle: sacco_info.current_cycle,
                timestamp: current_time,
            };
            
            self.contribution_records.write((group_id, caller, sacco_info.current_cycle), contribution_record);
            
            // Update SACCO totals
            let total_contributions = self.total_contributions.read(group_id);
            self.total_contributions.write(group_id, total_contributions + amount);
            
            sacco_info.total_contributions += amount;
            sacco_info.last_contribution_at = current_time;
            self.sacco_groups.write(group_id, sacco_info);
            
            self.emit(ContributionMade {
                group_id,
                member_address: caller,
                amount,
                cycle: sacco_info.current_cycle,
            });
        }

        fn get_contribution_balance(self: @ContractState, group_id: u256) -> u256 {
            self.total_contributions.read(group_id)
        }

        fn get_member_contribution(self: @ContractState, group_id: u256, member_address: ContractAddress) -> u256 {
            let member_info = self.sacco_members.read((group_id, member_address));
            member_info.total_contributed
        }

        fn start_rotation_cycle(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can start rotation cycles
            assert(self.is_admin.read((group_id, caller)), 'Only admin can start rotation cycles');
            
            let mut sacco_info = self.sacco_groups.read(group_id);
            assert(sacco_info.is_active, 'SACCO is not active');
            assert(!sacco_info.is_paused, 'SACCO is paused');
            
            // Increment cycle
            sacco_info.current_cycle += 1;
            self.sacco_groups.write(group_id, sacco_info);
            
            // Reset payout index for new cycle
            self.current_payout_index.write(group_id, 0);
            
            self.emit(RotationCycleStarted {
                group_id,
                new_cycle: sacco_info.current_cycle,
            });
        }

        fn process_payout(ref self: ContractState, group_id: u256, recipient_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can process payouts
            assert(self.is_admin.read((group_id, caller)), 'Only admin can process payouts');
            
            let sacco_info = self.sacco_groups.read(group_id);
            assert(sacco_info.is_active, 'SACCO is not active');
            
            // Check if recipient is a member and hasn't received payout this cycle
            assert(self.is_member(group_id, recipient_address), 'Recipient is not a member');
            
            let member_info = self.sacco_members.read((group_id, recipient_address));
            assert(!member_info.has_received_payout, 'Member already received payout this cycle');
            
            // Calculate payout amount (total contributions divided by member count)
            let total_contributions = self.total_contributions.read(group_id);
            let member_count = self.member_count.read(group_id);
            let payout_amount = total_contributions / member_count.into();
            
            // Transfer USDC tokens to recipient
            let usdc_contract_address: ContractAddress = USDC_CONTRACT.try_into().unwrap();
            let usdc_dispatcher = IERC20Dispatcher { contract_address: usdc_contract_address };
            
            usdc_dispatcher.transfer(recipient_address, payout_amount);
            
            // Update member payout status
            let mut updated_member = member_info;
            updated_member.has_received_payout = true;
            updated_member.payout_cycle = Option::Some(sacco_info.current_cycle);
            self.sacco_members.write((group_id, recipient_address), updated_member);
            
            // Update payout index
            let current_index = self.current_payout_index.read(group_id);
            self.current_payout_index.write(group_id, current_index + 1);
            
            self.emit(PayoutProcessed {
                group_id,
                recipient_address,
                amount: payout_amount,
                cycle: sacco_info.current_cycle,
            });
        }

        fn get_current_cycle(self: @ContractState, group_id: u256) -> u8 {
            let sacco_info = self.sacco_groups.read(group_id);
            sacco_info.current_cycle
        }

        fn get_next_payout_recipient(self: @ContractState, group_id: u256) -> ContractAddress {
            let payout_order = self.payout_order.read(group_id);
            let current_index = self.current_payout_index.read(group_id);
            
            // This is a simplified implementation
            // In a real system, you'd implement proper rotation logic
            payout_order.at(current_index.into())
        }

        fn emergency_withdraw(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can perform emergency withdrawal
            assert(self.is_admin.read((group_id, caller)), 'Only admin can perform emergency withdrawal');
            
            let sacco_info = self.sacco_groups.read(group_id);
            assert(sacco_info.is_active, 'SACCO is not active');
            
            // Get member's contribution amount
            let member_info = self.sacco_members.read((group_id, caller));
            let withdrawal_amount = member_info.total_contributed;
            
            // Transfer tokens back to member
            let usdc_contract_address: ContractAddress = USDC_CONTRACT.try_into().unwrap();
            let usdc_dispatcher = IERC20Dispatcher { contract_address: usdc_contract_address };
            
            usdc_dispatcher.transfer(caller, withdrawal_amount);
            
            // Update member status
            let mut updated_member = member_info;
            updated_member.total_contributed = 0;
            updated_member.is_active = false;
            self.sacco_members.write((group_id, caller), updated_member);
            
            self.emit(EmergencyWithdraw {
                group_id,
                member_address: caller,
                amount: withdrawal_amount,
            });
        }

        fn pause_sacco(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can pause SACCO
            assert(self.is_admin.read((group_id, caller)), 'Only admin can pause SACCO');
            
            let mut sacco_info = self.sacco_groups.read(group_id);
            sacco_info.is_paused = true;
            self.sacco_groups.write(group_id, sacco_info);
            
            self.emit(SaccoPaused { group_id, paused_by: caller });
        }

        fn resume_sacco(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can resume SACCO
            assert(self.is_admin.read((group_id, caller)), 'Only admin can resume SACCO');
            
            let mut sacco_info = self.sacco_groups.read(group_id);
            sacco_info.is_paused = false;
            self.sacco_groups.write(group_id, sacco_info);
            
            self.emit(SaccoResumed { group_id, resumed_by: caller });
        }
    }
}
