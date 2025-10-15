# 🏦 SACCO Decentralized App - Phase 1 Implementation

A comprehensive decentralized application for Savings and Credit Cooperative Organizations (SACCOs) built on Starknet using Scaffold-Stark 2.

## 📋 Overview

This implementation provides the core smart contract functionality for managing SACCO groups, including:
- SACCO group creation and management
- Member invitation and verification
- Contribution management and tracking
- Rotation cycle management and payouts
- Member role management and permissions
- Penalty system for late/absent contributions

## 🏗️ Smart Contract Architecture

### 1. SaccoCore Contract (`sacco_core.cairo`)
**Primary contract for SACCO group management**

**Key Features:**
- Create and manage SACCO groups
- Member enrollment and management
- Contribution collection and tracking
- Rotation cycle management
- Payout processing
- Emergency withdrawal functionality
- SACCO pause/resume capabilities

**Main Functions:**
```cairo
// Group Management
create_sacco_group(group_name, max_members, contribution_amount, contribution_frequency, admin_address)
get_sacco_info(group_id) -> SaccoInfo

// Member Management
join_sacco(group_id)
leave_sacco(group_id)
invite_member(group_id, member_address)
is_member(group_id, member_address) -> bool

// Contribution Management
make_contribution(group_id, amount)
get_contribution_balance(group_id) -> u256
get_member_contribution(group_id, member_address) -> u256

// Rotation & Payouts
start_rotation_cycle(group_id)
process_payout(group_id, recipient_address)
get_current_cycle(group_id) -> u8
get_next_payout_recipient(group_id) -> ContractAddress

// Emergency Functions
emergency_withdraw(group_id)
pause_sacco(group_id)
resume_sacco(group_id)
```

### 2. MemberManager Contract (`member_manager.cairo`)
**Advanced member verification and role management**

**Key Features:**
- Member verification system
- Role-based access control (Admin, Treasurer, Member)
- Member suspension and removal
- Contribution schedule management
- Individual contribution limits

**Main Functions:**
```cairo
// Verification
verify_member(group_id, member_address)
revoke_member_verification(group_id, member_address)
is_member_verified(group_id, member_address) -> bool

// Role Management
assign_admin_role(group_id, member_address)
assign_treasurer_role(group_id, member_address)
is_admin(group_id, member_address) -> bool
is_treasurer(group_id, member_address) -> bool

// Member Management
remove_member(group_id, member_address)
suspend_member(group_id, member_address, reason)
unsuspend_member(group_id, member_address)

// Configuration
update_contribution_schedule(group_id, new_amount, new_frequency)
set_member_contribution_limit(group_id, member_address, max_amount)
```

### 3. RotationManager Contract (`rotation_manager.cairo`)
**Sophisticated rotation cycle and penalty management**

**Key Features:**
- Cycle lifecycle management
- Contribution deadline tracking
- Penalty system for late/absent contributions
- Rotation order management
- Payout calculation and distribution

**Main Functions:**
```cairo
// Cycle Management
start_new_cycle(group_id)
end_current_cycle(group_id)
get_current_cycle(group_id) -> u8
get_cycle_status(group_id) -> CycleStatus

// Contribution Tracking
record_monthly_contribution(group_id, member_address, amount)
get_total_contributions_for_cycle(group_id, cycle) -> u256

// Payout Management
process_payout_cycle(group_id)
calculate_payout_amount(group_id, cycle) -> u256
get_next_payout_recipient(group_id) -> ContractAddress

// Penalty System
apply_late_penalty(group_id, member_address, penalty_amount)
apply_absence_penalty(group_id, member_address, penalty_amount)
get_member_penalties(group_id, member_address) -> u256
waive_penalty(group_id, member_address, penalty_amount)

// Configuration
set_rotation_order(group_id, rotation_order)
set_cycle_duration(group_id, duration_days)
set_contribution_deadline(group_id, deadline_days)
```

## 🚀 Quick Start

### Prerequisites
- Node.js >= v22
- Yarn v1 or v2+
- Git
- Starknet development tools (installed via `starkup`)

### Installation

1. **Install Starknet development tools:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.starkup.sh | sh
```

2. **Clone and setup the project:**
```bash
cd /home/monica/snapp
yarn install
```

3. **Start local blockchain:**
```bash
yarn chain
```

4. **Deploy contracts:**
```bash
yarn deploy
```

5. **Start frontend:**
```bash
yarn start
```

Visit `http://localhost:3000` to interact with the SACCO contracts.

## 📊 Data Structures

### SaccoInfo
```cairo
struct SaccoInfo {
    group_id: u256,
    group_name: ByteArray,
    admin_address: ContractAddress,
    max_members: u8,
    contribution_amount: u256,
    contribution_frequency: u8,
    total_contributions: u256,
    current_cycle: u8,
    is_active: bool,
    is_paused: bool,
    created_at: u64,
    last_contribution_at: u64,
}
```

### MemberInfo
```cairo
struct MemberInfo {
    member_address: ContractAddress,
    joined_at: u64,
    total_contributed: u256,
    has_received_payout: bool,
    payout_cycle: Option<u8>,
    is_active: bool,
}
```

### CycleStatus
```cairo
struct CycleStatus {
    cycle_number: u8,
    status: CycleState,
    start_date: u64,
    end_date: Option<u64>,
    total_contributions: u256,
    completed_payouts: u8,
    total_members: u8,
}
```

## 🔐 Security Features

1. **Access Control:**
   - Owner-based contract ownership
   - Role-based permissions (Admin, Treasurer, Member)
   - Function-level access restrictions

2. **Validation:**
   - Parameter validation for all functions
   - State consistency checks
   - Member verification requirements

3. **Emergency Functions:**
   - SACCO pause/resume capabilities
   - Emergency withdrawal options
   - Force cycle completion

4. **Penalty System:**
   - Late contribution penalties
   - Absence penalties
   - Configurable penalty rates
   - Penalty waiver mechanisms

## 🧪 Testing

Run the comprehensive test suite:

```bash
yarn test
```

The tests cover:
- SACCO group creation
- Member enrollment
- Contribution management
- Rotation cycles
- Payout processing
- Emergency functions
- Access control

## 📝 Events

All major operations emit events for frontend integration:

- `SaccoCreated` - When a new SACCO is created
- `MemberJoined` - When a member joins a SACCO
- `ContributionMade` - When a contribution is made
- `PayoutProcessed` - When a payout is processed
- `RotationCycleStarted` - When a new rotation cycle begins
- `PenaltyApplied` - When penalties are applied
- `SaccoPaused/Resumed` - When SACCO is paused/resumed

## 🔄 Integration with Frontend

The contracts are designed to work seamlessly with Scaffold-Stark 2's custom hooks:

```typescript
// Example usage in React components
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-stark";

// Read SACCO information
const { data: saccoInfo } = useScaffoldReadContract({
  contractName: "SaccoCore",
  functionName: "get_sacco_info",
  args: [groupId],
});

// Create a new SACCO
const { sendAsync: createSacco } = useScaffoldWriteContract({
  contractName: "SaccoCore",
  functionName: "create_sacco_group",
  args: [groupName, maxMembers, contributionAmount, frequency, adminAddress],
});
```

## 🌍 Network Configuration

The contracts support multiple networks:
- **Devnet** - For development and testing
- **Sepolia** - For testnet deployment
- **Mainnet** - For production deployment

Configure networks in `packages/nextjs/scaffold.config.ts`:
```typescript
const scaffoldConfig = {
  targetNetworks: [chains.sepolia], // or chains.devnet, chains.mainnet
  // ... other config
};
```

## 📈 Next Steps (Future Phases)

1. **Phase 2:** Personal Goals Module
2. **Phase 3:** Multi-Currency Wallet UI
3. **Phase 4:** Cross-Chain & Lightning Integration
4. **Phase 5:** Account Abstraction & Gas Paymaster
5. **Phase 6:** KYC & Compliance Module
6. **Phase 7:** Fiat Onramp/Offramp
7. **Phase 8:** Mobile-First Frontend

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For questions and support:
- Check the [Scaffold-Stark documentation](https://docs.scaffoldstark.com/)
- Open an issue on GitHub
- Join the community discussions

---

**Built with ❤️ using Scaffold-Stark 2 and Starknet**
