#[starknet::interface]
pub trait IRotationManager<TContractState> {
    // Rotation Cycle Management
    fn start_new_cycle(ref self: TContractState, group_id: u256);
    fn end_current_cycle(ref self: TContractState, group_id: u256);
    fn get_current_cycle(self: @TContractState, group_id: u256) -> u8;
    fn get_cycle_status(self: @TContractState, group_id: u256) -> CycleStatus;
    
    // Contribution Management
    fn record_monthly_contribution(
        ref self: TContractState, 
        group_id: u256, 
        member_address: ContractAddress, 
        amount: u256
    );
    fn get_member_contribution_for_cycle(
        self: @TContractState, 
        group_id: u256, 
        member_address: ContractAddress, 
        cycle: u8
    ) -> u256;
    fn get_total_contributions_for_cycle(self: @TContractState, group_id: u256, cycle: u8) -> u256;
    
    // Payout Management
    fn process_payout_cycle(ref self: TContractState, group_id: u256);
    fn calculate_payout_amount(self: @TContractState, group_id: u256, cycle: u8) -> u256;
    fn get_next_payout_recipient(self: @TContractState, group_id: u256) -> ContractAddress;
    fn mark_payout_completed(ref self: TContractState, group_id: u256, recipient: ContractAddress);
    
    // Penalty Management
    fn apply_late_penalty(ref self: TContractState, group_id: u256, member_address: ContractAddress, penalty_amount: u256);
    fn apply_absence_penalty(ref self: TContractState, group_id: u256, member_address: ContractAddress, penalty_amount: u256);
    fn get_member_penalties(self: @TContractState, group_id: u256, member_address: ContractAddress) -> u256;
    fn waive_penalty(ref self: TContractState, group_id: u256, member_address: ContractAddress, penalty_amount: u256);
    
    // Rotation Order Management
    fn set_rotation_order(ref self: TContractState, group_id: u256, rotation_order: Array<ContractAddress>);
    fn get_rotation_order(self: @TContractState, group_id: u256) -> Array<ContractAddress>;
    fn update_rotation_order(ref self: TContractState, group_id: u256, new_order: Array<ContractAddress>);
    
    // Cycle Configuration
    fn set_cycle_duration(ref self: TContractState, group_id: u256, duration_days: u8);
    fn set_contribution_deadline(ref self: TContractState, group_id: u256, deadline_days: u8);
    fn get_cycle_configuration(self: @TContractState, group_id: u256) -> CycleConfiguration;
    
    // Emergency Functions
    fn emergency_pause_cycle(ref self: TContractState, group_id: u256);
    fn emergency_resume_cycle(ref self: TContractState, group_id: u256);
    fn force_complete_cycle(ref self: TContractState, group_id: u256);
}

#[derive(Drop, Serde, starknet::Store)]
pub struct CycleStatus {
    pub cycle_number: u8,
    pub status: CycleState,
    pub start_date: u64,
    pub end_date: Option<u64>,
    pub total_contributions: u256,
    pub completed_payouts: u8,
    pub total_members: u8,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum CycleState {
    NotStarted,
    Active,
    ContributionPhase,
    PayoutPhase,
    Completed,
    Paused,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct CycleConfiguration {
    pub cycle_duration_days: u8,
    pub contribution_deadline_days: u8,
    pub penalty_rate_percent: u8, // e.g., 5 for 5%
    pub max_penalty_percent: u8, // e.g., 20 for 20%
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ContributionRecord {
    pub member_address: ContractAddress,
    pub amount: u256,
    pub cycle: u8,
    pub timestamp: u64,
    pub is_on_time: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct PayoutRecord {
    pub recipient_address: ContractAddress,
    pub amount: u256,
    pub cycle: u8,
    pub payout_date: u64,
    pub is_completed: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct PenaltyRecord {
    pub member_address: ContractAddress,
    pub penalty_type: PenaltyType,
    pub amount: u256,
    pub cycle: u8,
    pub timestamp: u64,
    pub is_waived: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum PenaltyType {
    LateContribution,
    Absence,
    Other,
}

#[starknet::contract]
pub mod RotationManager {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp
    };
    use super::{
        IRotationManager, CycleStatus, CycleState, CycleConfiguration, 
        ContributionRecord, PayoutRecord, PenaltyRecord, PenaltyType
    };
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
        NewCycleStarted: NewCycleStarted,
        CycleEnded: CycleEnded,
        ContributionRecorded: ContributionRecorded,
        PayoutProcessed: PayoutProcessed,
        PenaltyApplied: PenaltyApplied,
        PenaltyWaived: PenaltyWaived,
        RotationOrderSet: RotationOrderSet,
        CycleConfigurationUpdated: CycleConfigurationUpdated,
        CyclePaused: CyclePaused,
        CycleResumed: CycleResumed,
        CycleForceCompleted: CycleForceCompleted,
    }

    #[derive(Drop, starknet::Event)]
    struct NewCycleStarted {
        #[key]
        group_id: u256,
        cycle_number: u8,
        start_date: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct CycleEnded {
        #[key]
        group_id: u256,
        cycle_number: u8,
        end_date: u64,
        total_contributions: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionRecorded {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        amount: u256,
        cycle: u8,
        is_on_time: bool,
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
    struct PenaltyApplied {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        penalty_type: PenaltyType,
        amount: u256,
        cycle: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct PenaltyWaived {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        amount: u256,
        waived_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct RotationOrderSet {
        #[key]
        group_id: u256,
        order_count: u8,
        set_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CycleConfigurationUpdated {
        #[key]
        group_id: u256,
        duration_days: u8,
        deadline_days: u8,
        penalty_rate: u8,
        updated_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CyclePaused {
        #[key]
        group_id: u256,
        cycle: u8,
        paused_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CycleResumed {
        #[key]
        group_id: u256,
        cycle: u8,
        resumed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CycleForceCompleted {
        #[key]
        group_id: u256,
        cycle: u8,
        completed_by: ContractAddress,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        
        // Cycle Management
        current_cycles: Map<u256, u8>,
        cycle_statuses: Map<(u256, u8), CycleStatus>,
        cycle_configurations: Map<u256, CycleConfiguration>,
        
        // Contributions
        contribution_records: Map<(u256, ContractAddress, u8), ContributionRecord>,
        cycle_total_contributions: Map<(u256, u8), u256>,
        
        // Payouts
        payout_records: Map<(u256, ContractAddress, u8), PayoutRecord>,
        payout_order: Map<u256, Array<ContractAddress>>,
        current_payout_index: Map<u256, u8>,
        
        // Penalties
        penalty_records: Map<(u256, ContractAddress, u8), PenaltyRecord>,
        member_total_penalties: Map<(u256, ContractAddress), u256>,
        
        // Access Control
        is_group_admin: Map<(u256, ContractAddress), bool>,
        is_group_treasurer: Map<(u256, ContractAddress), bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl RotationManagerImpl of IRotationManager<ContractState> {
        fn start_new_cycle(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can start new cycles
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can start new cycles');
            
            let current_time = get_block_timestamp();
            let new_cycle = self.current_cycles.read(group_id) + 1;
            
            let cycle_status = CycleStatus {
                cycle_number: new_cycle,
                status: CycleState::Active,
                start_date: current_time,
                end_date: Option::None,
                total_contributions: 0,
                completed_payouts: 0,
                total_members: 0, // This would be set based on actual member count
            };
            
            self.current_cycles.write(group_id, new_cycle);
            self.cycle_statuses.write((group_id, new_cycle), cycle_status);
            
            self.emit(NewCycleStarted {
                group_id,
                cycle_number: new_cycle,
                start_date: current_time,
            });
        }

        fn end_current_cycle(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can end cycles
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can end cycles');
            
            let current_cycle = self.current_cycles.read(group_id);
            let mut cycle_status = self.cycle_statuses.read((group_id, current_cycle));
            
            assert(cycle_status.status == CycleState::Active, 'Cycle is not active');
            
            let current_time = get_block_timestamp();
            cycle_status.status = CycleState::Completed;
            cycle_status.end_date = Option::Some(current_time);
            
            self.cycle_statuses.write((group_id, current_cycle), cycle_status);
            
            self.emit(CycleEnded {
                group_id,
                cycle_number: current_cycle,
                end_date: current_time,
                total_contributions: cycle_status.total_contributions,
            });
        }

        fn get_current_cycle(self: @ContractState, group_id: u256) -> u8 {
            self.current_cycles.read(group_id)
        }

        fn get_cycle_status(self: @ContractState, group_id: u256) -> CycleStatus {
            let current_cycle = self.current_cycles.read(group_id);
            self.cycle_statuses.read((group_id, current_cycle))
        }

        fn record_monthly_contribution(
            ref self: ContractState, 
            group_id: u256, 
            member_address: ContractAddress, 
            amount: u256
        ) {
            let caller = get_caller_address();
            
            // Only admin or treasurer can record contributions
            assert(
                self.is_group_admin.read((group_id, caller)) || 
                self.is_group_treasurer.read((group_id, caller)), 
                'Only admin or treasurer can record contributions'
            );
            
            let current_time = get_block_timestamp();
            let current_cycle = self.current_cycles.read(group_id);
            let mut cycle_status = self.cycle_statuses.read((group_id, current_cycle));
            
            // Check if cycle is active
            assert(cycle_status.status == CycleState::Active, 'Cycle is not active');
            
            // Check if contribution is on time (simplified logic)
            let cycle_config = self.cycle_configurations.read(group_id);
            let deadline = cycle_status.start_date + (cycle_config.contribution_deadline_days as u64 * 86400);
            let is_on_time = current_time <= deadline;
            
            let contribution_record = ContributionRecord {
                member_address,
                amount,
                cycle: current_cycle,
                timestamp: current_time,
                is_on_time,
            };
            
            self.contribution_records.write((group_id, member_address, current_cycle), contribution_record);
            
            // Update cycle totals
            cycle_status.total_contributions += amount;
            self.cycle_statuses.write((group_id, current_cycle), cycle_status);
            
            let cycle_total = self.cycle_total_contributions.read((group_id, current_cycle));
            self.cycle_total_contributions.write((group_id, current_cycle), cycle_total + amount);
            
            self.emit(ContributionRecorded {
                group_id,
                member_address,
                amount,
                cycle: current_cycle,
                is_on_time,
            });
        }

        fn get_member_contribution_for_cycle(
            self: @ContractState, 
            group_id: u256, 
            member_address: ContractAddress, 
            cycle: u8
        ) -> u256 {
            let contribution_record = self.contribution_records.read((group_id, member_address, cycle));
            contribution_record.amount
        }

        fn get_total_contributions_for_cycle(self: @ContractState, group_id: u256, cycle: u8) -> u256 {
            self.cycle_total_contributions.read((group_id, cycle))
        }

        fn process_payout_cycle(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin or treasurer can process payouts
            assert(
                self.is_group_admin.read((group_id, caller)) || 
                self.is_group_treasurer.read((group_id, caller)), 
                'Only admin or treasurer can process payouts'
            );
            
            let current_cycle = self.current_cycles.read(group_id);
            let cycle_status = self.cycle_statuses.read((group_id, current_cycle));
            
            // Check if cycle is ready for payout phase
            assert(cycle_status.status == CycleState::Active, 'Cycle is not active');
            
            // Get next recipient from rotation order
            let payout_order = self.payout_order.read(group_id);
            let current_index = self.current_payout_index.read(group_id);
            
            // Check if there are more payouts to process
            assert(current_index < payout_order.len().try_into().unwrap(), 'No more payouts to process');
            
            let recipient = payout_order.at(current_index.into());
            let payout_amount = self.calculate_payout_amount(group_id, current_cycle);
            
            // Transfer USDC tokens to recipient
            let usdc_contract_address: ContractAddress = USDC_CONTRACT.try_into().unwrap();
            let usdc_dispatcher = IERC20Dispatcher { contract_address: usdc_contract_address };
            
            usdc_dispatcher.transfer(recipient, payout_amount);
            
            // Record payout
            let payout_record = PayoutRecord {
                recipient_address: recipient,
                amount: payout_amount,
                cycle: current_cycle,
                payout_date: get_block_timestamp(),
                is_completed: true,
            };
            
            self.payout_records.write((group_id, recipient, current_cycle), payout_record);
            
            // Update payout index
            self.current_payout_index.write(group_id, current_index + 1);
            
            // Update cycle status
            let mut updated_cycle_status = cycle_status;
            updated_cycle_status.completed_payouts += 1;
            self.cycle_statuses.write((group_id, current_cycle), updated_cycle_status);
            
            self.emit(PayoutProcessed {
                group_id,
                recipient_address: recipient,
                amount: payout_amount,
                cycle: current_cycle,
            });
        }

        fn calculate_payout_amount(self: @ContractState, group_id: u256, cycle: u8) -> u256 {
            let total_contributions = self.cycle_total_contributions.read((group_id, cycle));
            let payout_order = self.payout_order.read(group_id);
            let member_count = payout_order.len().try_into().unwrap();
            
            // Simple equal distribution
            total_contributions / member_count
        }

        fn get_next_payout_recipient(self: @ContractState, group_id: u256) -> ContractAddress {
            let payout_order = self.payout_order.read(group_id);
            let current_index = self.current_payout_index.read(group_id);
            
            payout_order.at(current_index.into())
        }

        fn mark_payout_completed(ref self: ContractState, group_id: u256, recipient: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin or treasurer can mark payouts as completed
            assert(
                self.is_group_admin.read((group_id, caller)) || 
                self.is_group_treasurer.read((group_id, caller)), 
                'Only admin or treasurer can mark payouts as completed'
            );
            
            let current_cycle = self.current_cycles.read(group_id);
            let mut payout_record = self.payout_records.read((group_id, recipient, current_cycle));
            
            payout_record.is_completed = true;
            self.payout_records.write((group_id, recipient, current_cycle), payout_record);
        }

        fn apply_late_penalty(ref self: ContractState, group_id: u256, member_address: ContractAddress, penalty_amount: u256) {
            let caller = get_caller_address();
            
            // Only admin or treasurer can apply penalties
            assert(
                self.is_group_admin.read((group_id, caller)) || 
                self.is_group_treasurer.read((group_id, caller)), 
                'Only admin or treasurer can apply penalties'
            );
            
            let current_cycle = self.current_cycles.read(group_id);
            let current_time = get_block_timestamp();
            
            let penalty_record = PenaltyRecord {
                member_address,
                penalty_type: PenaltyType::LateContribution,
                amount: penalty_amount,
                cycle: current_cycle,
                timestamp: current_time,
                is_waived: false,
            };
            
            self.penalty_records.write((group_id, member_address, current_cycle), penalty_record);
            
            // Update total penalties for member
            let total_penalties = self.member_total_penalties.read((group_id, member_address));
            self.member_total_penalties.write((group_id, member_address), total_penalties + penalty_amount);
            
            self.emit(PenaltyApplied {
                group_id,
                member_address,
                penalty_type: PenaltyType::LateContribution,
                amount: penalty_amount,
                cycle: current_cycle,
            });
        }

        fn apply_absence_penalty(ref self: ContractState, group_id: u256, member_address: ContractAddress, penalty_amount: u256) {
            let caller = get_caller_address();
            
            // Only admin or treasurer can apply penalties
            assert(
                self.is_group_admin.read((group_id, caller)) || 
                self.is_group_treasurer.read((group_id, caller)), 
                'Only admin or treasurer can apply penalties'
            );
            
            let current_cycle = self.current_cycles.read(group_id);
            let current_time = get_block_timestamp();
            
            let penalty_record = PenaltyRecord {
                member_address,
                penalty_type: PenaltyType::Absence,
                amount: penalty_amount,
                cycle: current_cycle,
                timestamp: current_time,
                is_waived: false,
            };
            
            self.penalty_records.write((group_id, member_address, current_cycle), penalty_record);
            
            // Update total penalties for member
            let total_penalties = self.member_total_penalties.read((group_id, member_address));
            self.member_total_penalties.write((group_id, member_address), total_penalties + penalty_amount);
            
            self.emit(PenaltyApplied {
                group_id,
                member_address,
                penalty_type: PenaltyType::Absence,
                amount: penalty_amount,
                cycle: current_cycle,
            });
        }

        fn get_member_penalties(self: @ContractState, group_id: u256, member_address: ContractAddress) -> u256 {
            self.member_total_penalties.read((group_id, member_address))
        }

        fn waive_penalty(ref self: ContractState, group_id: u256, member_address: ContractAddress, penalty_amount: u256) {
            let caller = get_caller_address();
            
            // Only admin can waive penalties
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can waive penalties');
            
            let current_cycle = self.current_cycles.read(group_id);
            let mut penalty_record = self.penalty_records.read((group_id, member_address, current_cycle));
            
            penalty_record.is_waived = true;
            self.penalty_records.write((group_id, member_address, current_cycle), penalty_record);
            
            // Reduce total penalties
            let total_penalties = self.member_total_penalties.read((group_id, member_address));
            if total_penalties >= penalty_amount {
                self.member_total_penalties.write((group_id, member_address), total_penalties - penalty_amount);
            }
            
            self.emit(PenaltyWaived {
                group_id,
                member_address,
                amount: penalty_amount,
                waived_by: caller,
            });
        }

        fn set_rotation_order(ref self: ContractState, group_id: u256, rotation_order: Array<ContractAddress>) {
            let caller = get_caller_address();
            
            // Only admin can set rotation order
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can set rotation order');
            
            self.payout_order.write(group_id, rotation_order.clone());
            self.current_payout_index.write(group_id, 0);
            
            self.emit(RotationOrderSet {
                group_id,
                order_count: rotation_order.len().try_into().unwrap(),
                set_by: caller,
            });
        }

        fn get_rotation_order(self: @ContractState, group_id: u256) -> Array<ContractAddress> {
            self.payout_order.read(group_id)
        }

        fn update_rotation_order(ref self: ContractState, group_id: u256, new_order: Array<ContractAddress>) {
            let caller = get_caller_address();
            
            // Only admin can update rotation order
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can update rotation order');
            
            self.payout_order.write(group_id, new_order.clone());
            
            self.emit(RotationOrderSet {
                group_id,
                order_count: new_order.len().try_into().unwrap(),
                set_by: caller,
            });
        }

        fn set_cycle_duration(ref self: ContractState, group_id: u256, duration_days: u8) {
            let caller = get_caller_address();
            
            // Only admin can set cycle duration
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can set cycle duration');
            
            let mut config = self.cycle_configurations.read(group_id);
            config.cycle_duration_days = duration_days;
            self.cycle_configurations.write(group_id, config);
            
            self.emit(CycleConfigurationUpdated {
                group_id,
                duration_days,
                deadline_days: config.contribution_deadline_days,
                penalty_rate: config.penalty_rate_percent,
                updated_by: caller,
            });
        }

        fn set_contribution_deadline(ref self: ContractState, group_id: u256, deadline_days: u8) {
            let caller = get_caller_address();
            
            // Only admin can set contribution deadline
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can set contribution deadline');
            
            let mut config = self.cycle_configurations.read(group_id);
            config.contribution_deadline_days = deadline_days;
            self.cycle_configurations.write(group_id, config);
            
            self.emit(CycleConfigurationUpdated {
                group_id,
                duration_days: config.cycle_duration_days,
                deadline_days,
                penalty_rate: config.penalty_rate_percent,
                updated_by: caller,
            });
        }

        fn get_cycle_configuration(self: @ContractState, group_id: u256) -> CycleConfiguration {
            self.cycle_configurations.read(group_id)
        }

        fn emergency_pause_cycle(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can pause cycles
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can pause cycles');
            
            let current_cycle = self.current_cycles.read(group_id);
            let mut cycle_status = self.cycle_statuses.read((group_id, current_cycle));
            
            cycle_status.status = CycleState::Paused;
            self.cycle_statuses.write((group_id, current_cycle), cycle_status);
            
            self.emit(CyclePaused {
                group_id,
                cycle: current_cycle,
                paused_by: caller,
            });
        }

        fn emergency_resume_cycle(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can resume cycles
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can resume cycles');
            
            let current_cycle = self.current_cycles.read(group_id);
            let mut cycle_status = self.cycle_statuses.read((group_id, current_cycle));
            
            cycle_status.status = CycleState::Active;
            self.cycle_statuses.write((group_id, current_cycle), cycle_status);
            
            self.emit(CycleResumed {
                group_id,
                cycle: current_cycle,
                resumed_by: caller,
            });
        }

        fn force_complete_cycle(ref self: ContractState, group_id: u256) {
            let caller = get_caller_address();
            
            // Only admin can force complete cycles
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can force complete cycles');
            
            let current_cycle = self.current_cycles.read(group_id);
            let mut cycle_status = self.cycle_statuses.read((group_id, current_cycle));
            
            cycle_status.status = CycleState::Completed;
            cycle_status.end_date = Option::Some(get_block_timestamp());
            self.cycle_statuses.write((group_id, current_cycle), cycle_status);
            
            self.emit(CycleForceCompleted {
                group_id,
                cycle: current_cycle,
                completed_by: caller,
            });
        }
    }
}
