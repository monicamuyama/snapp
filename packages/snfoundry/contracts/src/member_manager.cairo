#[starknet::interface]
pub trait IMemberManager<TContractState> {
    // Member Verification
    fn verify_member(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn revoke_member_verification(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn is_member_verified(self: @TContractState, group_id: u256, member_address: ContractAddress) -> bool;
    
    // Role Management
    fn assign_admin_role(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn revoke_admin_role(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn assign_treasurer_role(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn revoke_treasurer_role(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn is_admin(self: @TContractState, group_id: u256, member_address: ContractAddress) -> bool;
    fn is_treasurer(self: @TContractState, group_id: u256, member_address: ContractAddress) -> bool;
    
    // Member Management
    fn remove_member(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn suspend_member(ref self: TContractState, group_id: u256, member_address: ContractAddress, reason: ByteArray);
    fn unsuspend_member(ref self: TContractState, group_id: u256, member_address: ContractAddress);
    fn is_member_suspended(self: @TContractState, group_id: u256, member_address: ContractAddress) -> bool;
    
    // Contribution Schedule Management
    fn update_contribution_schedule(
        ref self: TContractState, 
        group_id: u256, 
        new_amount: u256, 
        new_frequency: u8
    );
    fn set_member_contribution_limit(
        ref self: TContractState, 
        group_id: u256, 
        member_address: ContractAddress, 
        max_amount: u256
    );
    fn get_member_contribution_limit(
        self: @TContractState, 
        group_id: u256, 
        member_address: ContractAddress
    ) -> u256;
    
    // Member Information
    fn get_member_details(self: @TContractState, group_id: u256, member_address: ContractAddress) -> MemberDetails;
    fn get_all_members(self: @TContractState, group_id: u256) -> Array<ContractAddress>;
    fn get_member_role(self: @TContractState, group_id: u256, member_address: ContractAddress) -> MemberRole;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct MemberDetails {
    pub member_address: ContractAddress,
    pub joined_at: u64,
    pub verified_at: Option<u64>,
    pub role: MemberRole,
    pub total_contributed: u256,
    pub contribution_limit: u256,
    pub is_suspended: bool,
    pub suspension_reason: Option<ByteArray>,
    pub suspension_date: Option<u64>,
    pub is_active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub enum MemberRole {
    Member,
    Treasurer,
    Admin,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SuspensionRecord {
    pub member_address: ContractAddress,
    pub reason: ByteArray,
    pub suspended_at: u64,
    pub suspended_by: ContractAddress,
}

#[starknet::contract]
pub mod MemberManager {
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp
    };
    use super::{IMemberManager, MemberDetails, MemberRole, SuspensionRecord};
    use core::option::OptionTrait;
    use core::option::Option;
    use core::array::ArrayTrait;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        MemberVerified: MemberVerified,
        MemberVerificationRevoked: MemberVerificationRevoked,
        AdminRoleAssigned: AdminRoleAssigned,
        AdminRoleRevoked: AdminRoleRevoked,
        TreasurerRoleAssigned: TreasurerRoleAssigned,
        TreasurerRoleRevoked: TreasurerRoleRevoked,
        MemberRemoved: MemberRemoved,
        MemberSuspended: MemberSuspended,
        MemberUnsuspended: MemberUnsuspended,
        ContributionScheduleUpdated: ContributionScheduleUpdated,
        MemberContributionLimitSet: MemberContributionLimitSet,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberVerified {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        verified_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberVerificationRevoked {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        revoked_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminRoleAssigned {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        assigned_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminRoleRevoked {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        revoked_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TreasurerRoleAssigned {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        assigned_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TreasurerRoleRevoked {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        revoked_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberRemoved {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        removed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberSuspended {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        reason: ByteArray,
        suspended_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberUnsuspended {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        unsuspended_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ContributionScheduleUpdated {
        #[key]
        group_id: u256,
        new_amount: u256,
        new_frequency: u8,
        updated_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MemberContributionLimitSet {
        #[key]
        group_id: u256,
        member_address: ContractAddress,
        max_amount: u256,
        set_by: ContractAddress,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        
        // Member verification
        verified_members: Map<(u256, ContractAddress), bool>,
        verification_timestamps: Map<(u256, ContractAddress), u64>,
        
        // Role management
        member_roles: Map<(u256, ContractAddress), MemberRole>,
        admin_members: Map<(u256, ContractAddress), bool>,
        treasurer_members: Map<(u256, ContractAddress), bool>,
        
        // Member details
        member_details: Map<(u256, ContractAddress), MemberDetails>,
        
        // Suspension management
        suspended_members: Map<(u256, ContractAddress), bool>,
        suspension_records: Map<(u256, ContractAddress), SuspensionRecord>,
        
        // Contribution limits
        member_contribution_limits: Map<(u256, ContractAddress), u256>,
        
        // Group contribution schedules
        group_contribution_amounts: Map<u256, u256>,
        group_contribution_frequencies: Map<u256, u8>,
        
        // Access control
        is_group_admin: Map<(u256, ContractAddress), bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl MemberManagerImpl of IMemberManager<ContractState> {
        fn verify_member(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can verify members
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can verify members');
            
            let current_time = get_block_timestamp();
            
            self.verified_members.write((group_id, member_address), true);
            self.verification_timestamps.write((group_id, member_address), current_time);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.verified_at = Option::Some(current_time);
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(MemberVerified {
                group_id,
                member_address,
                verified_by: caller,
            });
        }

        fn revoke_member_verification(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can revoke verification
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can revoke verification');
            
            self.verified_members.write((group_id, member_address), false);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.verified_at = Option::None;
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(MemberVerificationRevoked {
                group_id,
                member_address,
                revoked_by: caller,
            });
        }

        fn is_member_verified(self: @ContractState, group_id: u256, member_address: ContractAddress) -> bool {
            self.verified_members.read((group_id, member_address))
        }

        fn assign_admin_role(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only existing admin can assign admin role
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can assign admin role');
            
            self.member_roles.write((group_id, member_address), MemberRole::Admin);
            self.admin_members.write((group_id, member_address), true);
            self.is_group_admin.write((group_id, member_address), true);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.role = MemberRole::Admin;
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(AdminRoleAssigned {
                group_id,
                member_address,
                assigned_by: caller,
            });
        }

        fn revoke_admin_role(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can revoke admin role (but not their own)
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can revoke admin role');
            assert(caller != member_address, 'Cannot revoke your own admin role');
            
            self.member_roles.write((group_id, member_address), MemberRole::Member);
            self.admin_members.write((group_id, member_address), false);
            self.is_group_admin.write((group_id, member_address), false);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.role = MemberRole::Member;
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(AdminRoleRevoked {
                group_id,
                member_address,
                revoked_by: caller,
            });
        }

        fn assign_treasurer_role(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can assign treasurer role
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can assign treasurer role');
            
            self.member_roles.write((group_id, member_address), MemberRole::Treasurer);
            self.treasurer_members.write((group_id, member_address), true);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.role = MemberRole::Treasurer;
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(TreasurerRoleAssigned {
                group_id,
                member_address,
                assigned_by: caller,
            });
        }

        fn revoke_treasurer_role(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can revoke treasurer role
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can revoke treasurer role');
            
            self.member_roles.write((group_id, member_address), MemberRole::Member);
            self.treasurer_members.write((group_id, member_address), false);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.role = MemberRole::Member;
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(TreasurerRoleRevoked {
                group_id,
                member_address,
                revoked_by: caller,
            });
        }

        fn is_admin(self: @ContractState, group_id: u256, member_address: ContractAddress) -> bool {
            self.admin_members.read((group_id, member_address))
        }

        fn is_treasurer(self: @ContractState, group_id: u256, member_address: ContractAddress) -> bool {
            self.treasurer_members.read((group_id, member_address))
        }

        fn remove_member(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can remove members
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can remove members');
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.is_active = false;
            self.member_details.write((group_id, member_address), member_details);
            
            // Clear roles
            self.admin_members.write((group_id, member_address), false);
            self.treasurer_members.write((group_id, member_address), false);
            self.is_group_admin.write((group_id, member_address), false);
            
            self.emit(MemberRemoved {
                group_id,
                member_address,
                removed_by: caller,
            });
        }

        fn suspend_member(ref self: ContractState, group_id: u256, member_address: ContractAddress, reason: ByteArray) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Only admin can suspend members
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can suspend members');
            
            self.suspended_members.write((group_id, member_address), true);
            
            let suspension_record = SuspensionRecord {
                member_address,
                reason: reason.clone(),
                suspended_at: current_time,
                suspended_by: caller,
            };
            
            self.suspension_records.write((group_id, member_address), suspension_record);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.is_suspended = true;
            member_details.suspension_reason = Option::Some(reason);
            member_details.suspension_date = Option::Some(current_time);
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(MemberSuspended {
                group_id,
                member_address,
                reason,
                suspended_by: caller,
            });
        }

        fn unsuspend_member(ref self: ContractState, group_id: u256, member_address: ContractAddress) {
            let caller = get_caller_address();
            
            // Only admin can unsuspend members
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can unsuspend members');
            
            self.suspended_members.write((group_id, member_address), false);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.is_suspended = false;
            member_details.suspension_reason = Option::None;
            member_details.suspension_date = Option::None;
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(MemberUnsuspended {
                group_id,
                member_address,
                unsuspended_by: caller,
            });
        }

        fn is_member_suspended(self: @ContractState, group_id: u256, member_address: ContractAddress) -> bool {
            self.suspended_members.read((group_id, member_address))
        }

        fn update_contribution_schedule(
            ref self: ContractState, 
            group_id: u256, 
            new_amount: u256, 
            new_frequency: u8
        ) {
            let caller = get_caller_address();
            
            // Only admin can update contribution schedule
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can update contribution schedule');
            
            self.group_contribution_amounts.write(group_id, new_amount);
            self.group_contribution_frequencies.write(group_id, new_frequency);
            
            self.emit(ContributionScheduleUpdated {
                group_id,
                new_amount,
                new_frequency,
                updated_by: caller,
            });
        }

        fn set_member_contribution_limit(
            ref self: ContractState, 
            group_id: u256, 
            member_address: ContractAddress, 
            max_amount: u256
        ) {
            let caller = get_caller_address();
            
            // Only admin can set contribution limits
            assert(self.is_group_admin.read((group_id, caller)), 'Only admin can set contribution limits');
            
            self.member_contribution_limits.write((group_id, member_address), max_amount);
            
            // Update member details
            let mut member_details = self.member_details.read((group_id, member_address));
            member_details.contribution_limit = max_amount;
            self.member_details.write((group_id, member_address), member_details);
            
            self.emit(MemberContributionLimitSet {
                group_id,
                member_address,
                max_amount,
                set_by: caller,
            });
        }

        fn get_member_contribution_limit(
            self: @ContractState, 
            group_id: u256, 
            member_address: ContractAddress
        ) -> u256 {
            self.member_contribution_limits.read((group_id, member_address))
        }

        fn get_member_details(self: @ContractState, group_id: u256, member_address: ContractAddress) -> MemberDetails {
            self.member_details.read((group_id, member_address))
        }

        fn get_all_members(self: @ContractState, group_id: u256) -> Array<ContractAddress> {
            // This is a simplified implementation
            // In a real system, you'd maintain a list of members
            let mut members = ArrayTrait::new();
            // Implementation would iterate through all members
            members
        }

        fn get_member_role(self: @ContractState, group_id: u256, member_address: ContractAddress) -> MemberRole {
            self.member_roles.read((group_id, member_address))
        }
    }
}
