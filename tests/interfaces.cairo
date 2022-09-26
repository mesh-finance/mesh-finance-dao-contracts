%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20MESH:
    
    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end
    
    func burn(amount: Uint256) -> (success: felt):
    end

    func mint(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func set_minter(new_minter: felt) -> (new_minter: felt):
    end

    func transfer_ownership(new_owner: felt) -> (new_owner: felt):
    end

    func set_name_symbol(new_name: felt, new_symbol: felt):
    end

    func totalSupply() -> (totalSupply: Uint256):
    end

    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end

    func update_mining_parameters():
    end

    func start_epoch_time() -> (start_epoch_time: Uint256):
    end

    func start_epoch_time_write() -> (start_epoch_time: Uint256):
    end

    func rate() -> (rate: Uint256):
    end

    func available_supply() -> (supply: Uint256):
    end

    func minter() -> (address: felt):
    end

    func owner() -> (address: felt):
    end

    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func mining_epoch() -> (mining_epoch: felt):
    end

    func mintable_in_timeframe(start_timestamp: felt, end_timestamp: felt) -> (to_mint: Uint256):
    end
end