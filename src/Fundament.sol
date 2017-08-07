pragma solidity ^0.4.14;


/// @title Fundamental Contract
/// @dev The Fundamental contract contains useful functions and modifiers for other contracts to use.
contract Fundament {
    uint public creationTime = now;

    /// @dev requires that a condition is met
    modifier meets(bool condition) {
        require(condition);
        _;
    }

    /// @dev requires that a condition not be met
    modifier fails(bool condition) {
        require(!condition);
        _;
    }

    /// @dev If this modifier is used, it will prepend a check that only passes
    /// @dev if the function is called from the given address.
    modifier onlyby(address account) {
        require(msg.sender == account);
        _;
    }

    /// @dev If this modifier is used, it will prepend a check that only passes
    /// @dev if the function is not called from the given address.
    modifier notby(address account) {
        require(account != 0);
        _;
    }

    modifier isdefined(address value) {
        require(value != 0);
        _;
    }

    modifier isundefined(address value) {
        require(value == 0);
        _;
    }

/*    modifier isdefined(uint value) {
        require(value != 0);
        _;
    }

    modifier isundefined(uint value) {
        require(value == 0);
        _;
    }*/

    // Assure that the message came with enough to
    // cover the required amount
    modifier sentmorethan(uint amount) {
        require(msg.value >= amount);
        _;
    }

    // This modifier requires a certain
    // fee being associated with a function call.
    // If the caller sent too much, he or she is
    // refunded, but only after the function body.
    // This was dangerous before Solidity version 0.4.0,
    // where it was possible to skip the part after `_;`.
    modifier costs(uint amount) {
        require(msg.value >= amount);
        _;
        if (msg.value > amount)
        msg.sender.transfer(msg.value - amount);
    }

    // Modifiers can receive arguments:
    modifier requiresfunding(uint price) {
        require(msg.value >= price);
        _;
    }

    modifier onlyafter(uint timeInterval) {
        require(creationTime+timeInterval <= now);
        _;
    }

    function onlyBy(address a) onlyby(a) returns(bool) { return true; }
    function isDefined(address a) isdefined(a) returns(bool) { return true; }
    function isUndefined(address a) isundefined(a) returns(bool) { return true; }
    function onlyAfter(uint interval) onlyafter(interval) returns(bool) { return true; }
}


/// @title Ownable Contract
/// @dev Base class for contracts that know who owns it.
contract Ownable is Fundament {
    modifier onlyowner {
        require(onlyBy(owner));
        _;
    }

    modifier isowned {
        require(isDefined(owner));
        _;
    }

    modifier isdisowned {
        require(isUndefined(owner));
        _;
    }

    address owner = msg.sender;
}


/// @title Mortal Contract
/// @dev A contract that is destroyed upon demand by the owner
contract Mortal is Ownable {
    /// If there is a serious problem, the owner my choose to destroy the contract.
    function destroy() onlyowner {
        selfdestruct(owner);
    }
}


/// @title Transferable Contract
/// @dev A contract that may be transferred to another owner
contract Transferable is Mortal {
    /// Make `newOwner` the new owner of this contract.
    function grantOwnership(address newOwner) onlyowner {
        owner = newOwner;
    }

    /// Erase ownership information.
    /// May only be called 2 weeks after
    /// the contract has been created.
    function disown() onlyowner onlyafter(2 weeks) {
        owner = 0;
    }

    /// Gain ownership.
    function takeOver() isdisowned {
        owner = msg.sender;
    }
}


/// @title Account Registry
contract AccountRegistry is Transferable {
    function AccountRegistry(uint initialPrice) { price = initialPrice; }

    modifier isregistered(address acct) {
        require(registry[acct]);
        _;
    }

    modifier isunregistered(address acct) {
        require(!registry[acct]);
        _;
    }

    /// Adds the sender's address to the registry
    function register() payable isunregistered(msg.sender) costs(price) {
        registry[msg.sender] = true;
    }

    /// Removes the sender's address from the registry
    function unregister() payable isregistered(msg.sender) costs(price) {
        registry[msg.sender] = false;
    }

    /// Allows the owner to modify the registration status of an account
    function registerAnother(address acct, bool ok) onlyowner {
        registry[acct] = ok;
    }

    /// Changes the price registry for new registrants.
    function changePrice(uint _price) onlyowner {
        price = _price;
    }

    uint price;
    mapping (address => bool) registry;
}


contract Guarded {
    bool _locked;
    modifier unsafe() {
        require(!_locked);
        _;
        assert(!_locked);
    }

    /// @dev re-entrant
    /// @dev uses _locked to protect against re-entry, _locked must never be allowed
    /// @dev to change in any other way.
    modifier reentrant() {
        require(!_locked);
        _locked = true;
        _;
        assert(_locked);
        _locked = false;
    }
}



/// @dev Models a uint -> uint mapping where it is possible to iterate over all keys.
library IterableMapping {
    struct Map {
        mapping(uint => IndexValue) data;
        KeyFlag[] keys;
        uint size;
    }
    struct IndexValue { uint keyIndex; uint value; }
    struct KeyFlag { uint key; bool deleted; }

    function insert(Map storage self, uint key, uint value) returns (bool replaced) {
        uint keyIndex = self.data[key].keyIndex;
        self.data[key].value = value;
        if (keyIndex > 0) {
            return true;
        } else {
            keyIndex = self.keys.length++;
            self.data[key].keyIndex = keyIndex + 1;
            self.keys[keyIndex].key = key;
            self.size++;
            return false;
        }
    }

    function remove(Map storage self, uint key) returns (bool success) {
        uint keyIndex = self.data[key].keyIndex;
        if (keyIndex == 0)
            return false;
        
        delete self.data[key];
        self.keys[keyIndex - 1].deleted = true;
        self.size--;
    }

    function contains(Map storage self, uint key) returns (bool) {
        return self.data[key].keyIndex > 0;
    }

    function iterateStart(Map storage self) returns (uint keyIndex) {
        return iterateNext(self, uint(-1));
    }

    function iterateValid(Map storage self, uint keyIndex) returns (bool) {
        return keyIndex < self.keys.length;
    }

    function iterateNext(Map storage self, uint keyIndex) returns (uint) {
        keyIndex++;
        while (keyIndex < self.keys.length && self.keys[keyIndex].deleted) {
            keyIndex++;
        }
        return keyIndex;
    }

    function iterateGet(Map storage self, uint keyIndex) returns (uint key, uint value) {
        key = self.keys[keyIndex].key;
        value = self.data[key].value;
    }
}

