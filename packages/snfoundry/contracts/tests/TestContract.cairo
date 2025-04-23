use snforge_std::EventSpyAssertionsTrait;
use snforge_std::{ 
    DeclareResultTrait, ContractClassTrait, 
    declare, 
    spy_events, 
    start_cheat_caller_address,
    stop_cheat_caller_address
};
use starknet::{ ContractAddress };
use contracts::counter:: { Counter, ICounterDispatcher, ICounterDispatcherTrait, ICounterSafeDispatcher, ICounterSafeDispatcherTrait };
use openzeppelin_access::ownable::interface::{ IOwnableDispatcher, IOwnableDispatcherTrait };

const ZERO_COUNT: u32 = 0;

// Test accounts
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn USER_1() -> ContractAddress {
    'USER_1'.try_into().unwrap()
}


// Utility deploy function
fn __deploy__(init_value: u32) -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher) {
    // declare
    let contract_class = declare("Counter").unwrap().contract_class();

    // serialize constructor arguments
    let mut calldata: Array<felt252> = array![];
    init_value.serialize(ref calldata);
    OWNER().serialize(ref calldata);


    // deploy
    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy contract');

    let counter = ICounterDispatcher{contract_address: contract_address};
    let ownable = IOwnableDispatcher{contract_address: contract_address};
    let safe_dispatcher = ICounterSafeDispatcher{contract_address: contract_address};
    (counter, ownable, safe_dispatcher)
}

#[ignore] // to ignore tests
#[test]
fn test_counter_deployment() {
    let (counter, ownable, _) = __deploy__(ZERO_COUNT);

    // count 1
    let count_1 = counter.get_counter();
    assert(count_1 == ZERO_COUNT, 'Counter is zero');
    assert(ownable.owner() == OWNER(), 'Owner is set');
}

#[ignore]
#[test]
fn test_increase_counter() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);

    // count 1
    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'Counter is zero');

    // increase counter
    counter.increase_counter();
    let count_2 = counter.get_counter();
    assert(count_2 == count_1 + 1, 'Should be increased by 1');
    
}

#[test]
fn test_emitted_incresed_event() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);
    let mut spy = spy_events();

    // Mock a caller
    start_cheat_caller_address(counter.contract_address, USER_1());
    // count 1
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);

    spy.assert_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Increased(
                    Counter::Increased {
                        account: USER_1(),
                    }
                )
            )
        ]
    );

    spy.assert_not_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Decreased(
                    Counter::Decreased {
                        account: USER_1(),
                    }
                )
            )
        ]
    )
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_decrease_counter() {
    let (counter, _, safe_dispatcher) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'Counter is zero');
    
    match safe_dispatcher.decrease_counter() {
        Result::Ok(_) => panic!("Cannot decrease 0"),
        Result::Err(e) => assert(
            *e[0] == 'Decreasing Empty Counter',
            *e.at(0)
        )
    }
}

#[test]
#[should_panic(expected: 'Decreasing Empty Counter')]
fn test_panic_decrease_counter() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'Counter is zero');

    counter.decrease_counter();
}

#[test]
fn test_sucessful_decrease_counter() {
    let (counter, _, _) = __deploy__(5);

    let count_1 = counter.get_counter();

    assert(count_1 == 5, 'Invalid count');

    // Execute decrease transaction
    counter.decrease_counter();

    let final_count = counter.get_counter();

    assert(final_count == count_1 - 1, 'Invalid count');
       
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_reset_counter_by_non_owner() {
    let (counter, _, safe_dispatcher) = __deploy__(0);

    assert(counter.get_counter() == ZERO_COUNT, 'Invalid count');

    start_cheat_caller_address(counter.contract_address, USER_1());

    match safe_dispatcher.reset_counter() {
        Result::Ok(_) => panic!("Cannot reset"),
        Result::Err(e) => assert(
            *e[0] == 'Caller is not the owner',
            *e.at(0)
        )
    }
}

#[test]
fn test_successful_reset_counter() {
    let (counter, _, _) = __deploy__(5);

    let count_1 = counter.get_counter();

    assert(count_1 == 5, 'Invalid count');

    start_cheat_caller_address(counter.contract_address, OWNER());
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);

    assert(counter.get_counter() == ZERO_COUNT, 'Counter should be reset to 0');
}