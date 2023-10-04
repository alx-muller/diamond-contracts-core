pragma solidity =0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IKeyGenHistory.sol";
import "./interfaces/IValidatorSetHbbft.sol";
import "./interfaces/IStakingHbbft.sol";

contract KeyGenHistory is Initializable, OwnableUpgradeable, IKeyGenHistory {
    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!
    address[] public validatorSet;

    mapping(address => bytes) public parts;
    mapping(address => bytes[]) public acks;

    /// @dev number of parts written in this key generation round.
    uint128 public numberOfPartsWritten;

    /// @dev number of full ack sets written in this key generation round.
    uint128 public numberOfAcksWritten;

    /// @dev The address of the `ValidatorSetHbbft` contract.
    IValidatorSetHbbft public validatorSetContract;

    /// @dev round counter for key generation rounds.
    /// in an ideal world, every key generation only requires one try,
    /// and all validators manage to write their acks and parts,
    /// so it is possible to achieve this goal in round 0.
    /// in the real world, there are failures,
    /// this mechanics helps covering that,
    /// by revoking transactions, that were targeted for an earlier key gen round.
    /// more infos: https://github.com/DMDcoin/hbbft-posdao-contracts/issues/106
    uint256 public currentKeyGenRound;

    event NewValidatorsSet(address[] newValidatorSet);

    /// @dev Ensures the caller is ValidatorSet contract.
    modifier onlyValidatorSet() {
        require(
            msg.sender == address(validatorSetContract),
            "Must by executed by validatorSetContract"
        );
        _;
    }

    /// @dev ensures that Key Generation functions are called with wrong _epoch
    /// parameter to prevent old and wrong transactions get picked up.
    modifier onlyUpcommingEpoch(uint256 _epoch) {
        require(
            IStakingHbbft(validatorSetContract.getStakingContract())
                .stakingEpoch() +
                1 ==
                _epoch,
            "Key Generation function called with wrong _epoch parameter."
        );
        _;
    }

    /// @dev ensures that Key Generation functions are called with wrong _epoch
    /// parameter to prevent old and wrong transactions get picked up.
    modifier onlyCorrectRound(uint256 _roundCounter) {
        require(
            currentKeyGenRound == _roundCounter,
            "Key Generation function called with wrong _roundCounter parameter."
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Prevents initialization of implementation contract
        _disableInitializers();
    }

    function initialize(
        address _contractOwner,
        address _validatorSetContract,
        address[] memory _validators,
        bytes[] memory _parts,
        bytes[][] memory _acks
    ) external initializer {
        require(_contractOwner != address(0), "Owner address must not be 0");
        require(_validators.length != 0, "Validators must be more than 0.");
        require(_validators.length == _parts.length, "Wrong number of Parts!");
        require(_validators.length == _acks.length, "Wrong number of Acks!");
        require(
            _validatorSetContract != address(0),
            "Validator contract address cannot be 0."
        );

        __Ownable_init();
        _transferOwnership(_contractOwner);

        validatorSetContract = IValidatorSetHbbft(_validatorSetContract);

        for (uint256 i = 0; i < _validators.length; i++) {
            parts[_validators[i]] = _parts[i];
            acks[_validators[i]] = _acks[i];
        }

        currentKeyGenRound = 1;
    }

    /// @dev Clears the state (acks and parts of previous validators.
    /// @param _prevValidators The list of previous validators.
    function clearPrevKeyGenState(address[] calldata _prevValidators)
        external
        onlyValidatorSet
    {
        for (uint256 i = 0; i < _prevValidators.length; i++) {
            delete parts[_prevValidators[i]];
            delete acks[_prevValidators[i]];
        }
        numberOfPartsWritten = 0;
        numberOfAcksWritten = 0;
    }

    function notifyKeyGenFailed() external onlyValidatorSet {
        currentKeyGenRound = currentKeyGenRound + 1;
    }

    function notifyNewEpoch() external onlyValidatorSet {
        currentKeyGenRound = 1;
    }

    function writePart(
        uint256 _upcommingEpoch,
        uint256 _roundCounter,
        bytes memory _part
    )
        public
        onlyUpcommingEpoch(_upcommingEpoch)
        onlyCorrectRound(_roundCounter)
    {
        // It can only be called by a new validator which is elected but not yet finalized...
        // ...or by a validator which is already in the validator set.
        require(
            validatorSetContract.isPendingValidator(msg.sender),
            "Sender is not a pending validator"
        );
        require(parts[msg.sender].length == 0, "Parts already submitted!");
        parts[msg.sender] = _part;
        numberOfPartsWritten++;
    }

    function writeAcks(
        uint256 _upcommingEpoch,
        uint256 _roundCounter,
        bytes[] memory _acks
    )
        public
        onlyUpcommingEpoch(_upcommingEpoch)
        onlyCorrectRound(_roundCounter)
    {
        // It can only be called by a new validator which is elected but not yet finalized...
        // ...or by a validator which is already in the validator set.
        require(
            validatorSetContract.isPendingValidator(msg.sender),
            "Sender is not a pending validator"
        );
        require(acks[msg.sender].length == 0, "Acks already submitted");
        acks[msg.sender] = _acks;
        numberOfAcksWritten++;
    }

    function getPart(address _val) external view returns (bytes memory) {
        return parts[_val];
    }

    function getAcksLength(address val) external view returns (uint256) {
        return acks[val].length;
    }

    function getCurrentKeyGenRound() external view returns (uint256) {
        return currentKeyGenRound;
    }

    function getNumberOfKeyFragmentsWritten()
        external
        view
        returns (uint128, uint128)
    {
        return (numberOfPartsWritten, numberOfAcksWritten);
    }
}
