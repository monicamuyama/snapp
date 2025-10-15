use contracts::sacco_simple::{ISaccoSimpleDispatcher, ISaccoSimpleDispatcherTrait};
use openzeppelin_testing::declare_and_deploy;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{CheatSpan, cheat_caller_address};
use starknet::ContractAddress;

// Test addresses
const OWNER: ContractAddress = 0x02dA5254690b46B9C4059C25366D1778839BE63C142d899F0306fd5c312A5918
    .try_into()
    .unwrap();

const MEMBER1: ContractAddress = 0x03dA5254690b46B9C4059C25366D1778839BE63C142d899F0306fd5c312A5918
    .try_into()
    .unwrap();

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(OWNER);
    declare_and_deploy(name, calldata)
}

#[test]
fn test_create_sacco() {
    let contract_address = deploy_contract("SaccoSimple");
    let dispatcher = ISaccoSimpleDispatcher { contract_address };

    let sacco_name: ByteArray = "Test SACCO";
    let max_members = 10;
    let contribution_amount = 1000000000000000000; // 1 USDC (18 decimals)

    cheat_caller_address(contract_address, OWNER, CheatSpan::TargetCalls(1));
    dispatcher.create_sacco(
        sacco_name.try_into().unwrap(),
        max_members,
        contribution_amount
    );

    let total_saccos = dispatcher.get_total_saccos();
    assert(total_saccos == 1, 'Should have 1 SACCO');

    let sacco_info = dispatcher.get_sacco_info(1);
    assert(sacco_info.id == 1, 'SACCO ID should be 1');
    let expected_name: ByteArray = "Test SACCO";
    assert(sacco_info.name == expected_name, 'Name match');
    assert(sacco_info.max_members == max_members, 'Max members');
    assert(sacco_info.contribution_amount == contribution_amount, 'Amount mismatch');
    assert(sacco_info.is_active == true, 'Active');
}

#[test]
fn test_join_sacco() {
    let contract_address = deploy_contract("SaccoSimple");
    let dispatcher = ISaccoSimpleDispatcher { contract_address };

    // First create a SACCO
    cheat_caller_address(contract_address, OWNER, CheatSpan::TargetCalls(1));
    dispatcher.create_sacco(
        "Test SACCO",
        10,
        1000000000000000000
    );

    // Then join as member1
    cheat_caller_address(contract_address, MEMBER1, CheatSpan::TargetCalls(1));
    dispatcher.join_sacco(1);

    let sacco_info = dispatcher.get_sacco_info(1);
    assert(sacco_info.member_count == 1, '1 member');

    let is_member = dispatcher.is_member(1, MEMBER1);
    assert(is_member == true, 'Is member');
}

#[test]
fn test_get_balance() {
    let contract_address = deploy_contract("SaccoSimple");
    let dispatcher = ISaccoSimpleDispatcher { contract_address };

    // Create a SACCO
    cheat_caller_address(contract_address, OWNER, CheatSpan::TargetCalls(1));
    dispatcher.create_sacco(
        "Test SACCO",
        10,
        1000000000000000000
    );

    let balance = dispatcher.get_balance(1);
    assert(balance == 0, 'Balance 0');
}