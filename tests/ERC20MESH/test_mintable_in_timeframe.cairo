%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, deploy, get_contract_address
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_unsigned_div_rem, uint256_mul
from starkware.cairo.common.pow import pow
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from tests.ERC20MESH.interfaces import IERC20MESH
from starkware.starknet.common.syscalls import get_block_timestamp

const WEEK = 86400 * 7;
const YEAR = 86400 * 365;
const INITIAL_SUPPLY = 1303030303;  // 43% of 3.03 billion total supply

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;

    local deployer_signer = 1;
    local user_1_signer = 2;

    %{
        context.deployer_signer = ids.deployer_signer
        context.user_1_signer = ids.user_1_signer
        context.user_1_address = deploy_contract("./contracts/test/Account.cairo", [context.user_1_signer]).contract_address
        context.deployer_address = deploy_contract("./contracts/test/Account.cairo", [context.deployer_signer]).contract_address
        # This is to ensure that the constructor is affected by the warp cheatcode
        declared = declare("./contracts/ERC20MESH.cairo")
        prepared = prepare(declared, [11, 1, context.deployer_address])
        stop_warp = warp(86400 * 365, target_contract_address=prepared.contract_address)
        context.erc20_mesh_address = prepared.contract_address
        deploy(prepared)
        stop_warp()
    %}

    local erc20_mesh_address;
    local deployer_address;
    %{
        ids.erc20_mesh_address = context.erc20_mesh_address
        ids.deployer_address = context.deployer_address
    %}

    // Update initial mining parameters
    %{ stop_warp = warp(86400 * 365 + 86401, target_contract_address=ids.erc20_mesh_address) %}
    %{ stop_prank = start_prank(ids.deployer_address, target_contract_address=ids.erc20_mesh_address) %}
    IERC20MESH.update_mining_parameters(contract_address=erc20_mesh_address);
    %{ stop_prank() %}
    %{ stop_warp() %}

    return ();
}

@external
func setup_mintable_in_timeframe{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() {
    %{ given(decimal = strategy.integers(min_value=1, max_value=7)) %}
    return ();
}

@external
func test_mintable_in_timeframe{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(decimal: felt){
    alloc_locals;

    local erc20_mesh_address;
    local deployer_address;
    local user_1_address;

    %{
        ids.erc20_mesh_address = context.erc20_mesh_address
        ids.deployer_address = context.deployer_address
        ids.user_1_address = context.user_1_address
    %}

    // Fast forward since initial creation time
    let (delay) = pow(10, decimal);
    let (t0) = IERC20MESH.start_epoch_time(contract_address=erc20_mesh_address);
    %{ stop_warp = warp(86400 * 365 + 86401 + ids.delay, target_contract_address=ids.erc20_mesh_address) %}
    let t1 = 86400 * 365 + 86401 + delay;
    _update_mining_parameters_if_needed(t1, t0, erc20_mesh_address);
    let (available_supply) = IERC20MESH.available_supply(contract_address=erc20_mesh_address);
    let (mintable) = IERC20MESH.mintable_in_timeframe(contract_address=erc20_mesh_address, start_timestamp=t0.low, end_timestamp=t1);
    %{ stop_warp() %}

    assert_le(mintable.low, available_supply.low - INITIAL_SUPPLY * 10 ** 18);

    return ();
}

@external
func setup_random_range_year_one{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() {
    let YEAR = 86400 * 365;
    let YEAR_HALF = 86400 * 182;
    %{ 
        given(
            time = strategy.integers(min_value=0, max_value=ids.YEAR_HALF),
            time2 = strategy.integers(min_value=ids.YEAR_HALF, max_value=ids.YEAR),
        )
    %}
    return ();
}

@external
func test_random_range_year_one{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(time: felt, time2: felt){
    alloc_locals;

    local erc20_mesh_address;
    local deployer_address;
    local user_1_address;

    %{
        ids.erc20_mesh_address = context.erc20_mesh_address
        ids.deployer_address = context.deployer_address
        ids.user_1_address = context.user_1_address
    %}

    // Fast forward since initial creation time
    let (creation_time) = IERC20MESH.start_epoch_time(contract_address=erc20_mesh_address);
    let start_time = creation_time.low + time;
    let end_time = creation_time.low + time2;
    let (rate) = IERC20MESH.rate(contract_address=erc20_mesh_address);

    let (mintable) = IERC20MESH.mintable_in_timeframe(contract_address=erc20_mesh_address, start_timestamp=start_time, end_timestamp=end_time);
    
    assert mintable.low = rate.low * (end_time - start_time);
    return ();
}

@external
func test_random_range_multiple_epochs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;

    local erc20_mesh_address;
    local deployer_address;
    local user_1_address;

    %{
        ids.erc20_mesh_address = context.erc20_mesh_address
        ids.deployer_address = context.deployer_address
        ids.user_1_address = context.user_1_address
    %}
    let YEAR = 86400 * 365;

    // Fast forward since initial creation time
    let (creation_time) = IERC20MESH.start_epoch_time(contract_address=erc20_mesh_address);
    let start_time = creation_time.low;
    let end_time = YEAR * 6;
    let (rate) = IERC20MESH.rate(contract_address=erc20_mesh_address);

    %{ stop_warp = warp(ids.creation_time.low + ids.YEAR, target_contract_address=ids.erc20_mesh_address) %}
    IERC20MESH.update_mining_parameters(contract_address=erc20_mesh_address);
    %{ stop_warp() %}

    %{ stop_warp = warp(ids.creation_time.low + 2 * ids.YEAR, target_contract_address=ids.erc20_mesh_address) %}
    IERC20MESH.update_mining_parameters(contract_address=erc20_mesh_address);
    %{ stop_warp() %}

    %{ stop_warp = warp(ids.creation_time.low + 3 * ids.YEAR, target_contract_address=ids.erc20_mesh_address) %}
    IERC20MESH.update_mining_parameters(contract_address=erc20_mesh_address);
    %{ stop_warp() %}

    %{ stop_warp = warp(ids.creation_time.low + 4 * ids.YEAR, target_contract_address=ids.erc20_mesh_address) %}
    IERC20MESH.update_mining_parameters(contract_address=erc20_mesh_address);
    %{ stop_warp() %}

    %{ stop_warp = warp(ids.creation_time.low + 5 * ids.YEAR, target_contract_address=ids.erc20_mesh_address) %}
    IERC20MESH.update_mining_parameters(contract_address=erc20_mesh_address);
    %{ stop_warp() %}

    let (mintable) = IERC20MESH.mintable_in_timeframe(contract_address=erc20_mesh_address, start_timestamp=start_time, end_timestamp=end_time);
    
    assert_le(mintable.low, rate.low * end_time);
    return ();
}

@external
func setup_available_supply{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() {
    let YEAR = 86400 * 365;
    %{ given(duration = strategy.integers(min_value=0, max_value=ids.YEAR)) %}
    return ();
}

@external
func test_available_supply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(duration: felt){
    alloc_locals;

    local erc20_mesh_address;
    local deployer_address;
    local user_1_address;

    %{
        ids.erc20_mesh_address = context.erc20_mesh_address
        ids.deployer_address = context.deployer_address
        ids.user_1_address = context.user_1_address
    %}

    // Fast forward since initial creation time
    let (creation_time) = IERC20MESH.start_epoch_time(contract_address=erc20_mesh_address);
    let (initial_supply) = IERC20MESH.totalSupply(contract_address=erc20_mesh_address);
    let (rate) = IERC20MESH.rate(contract_address=erc20_mesh_address);

    let next_timestamp = creation_time.low + duration;
    %{ stop_warp = warp(ids.next_timestamp, target_contract_address=ids.erc20_mesh_address) %}
    let (available_supply) = IERC20MESH.available_supply(contract_address=erc20_mesh_address);
    let (supply_diff, _) = uint256_mul(Uint256(duration, 0), rate);
    let (expected_supply, _) = uint256_add(initial_supply, supply_diff);
    assert expected_supply = available_supply;
    %{ stop_warp() %}

    return ();
}

func _update_mining_parameters_if_needed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(current_timestamp: felt, epoch_start: Uint256, erc20_mesh_address: felt) -> (epoch_start: Uint256){
    let is_time_difference_less_than_year = is_le(current_timestamp - epoch_start.low, YEAR);
    // If time difference is greater than 1 year
    if (is_time_difference_less_than_year == 0) {
        IERC20MESH.update_mining_parameters(contract_address=erc20_mesh_address);
        let (new_epoch_start) = IERC20MESH.start_epoch_time(contract_address=erc20_mesh_address);
        return (epoch_start=new_epoch_start);
    } else {
        return (epoch_start=epoch_start);
    }
}