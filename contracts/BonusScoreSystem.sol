pragma solidity =0.8.25;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { ZeroAddress } from "./lib/Errors.sol";
import { ScoringFactor, IBonusScoreSystem } from "./interfaces/IBonusScoreSystem.sol";

contract BonusScoreSystem is Initializable, OwnableUpgradeable, IBonusScoreSystem {
    uint256 public constant DEFAULT_STAND_BY_FACTOR = 15;
    uint256 public constant DEFAULT_NO_KEY_WRITE_FACTOR = 100;
    uint256 public constant DEFAULT_BAD_PERF_FACTOR = 100;
    uint256 public constant MIN_SCORE = 1;
    uint256 public constant MAX_SCORE = 1000;

    mapping(ScoringFactor => uint256) private _factors;
    mapping(address => uint256) private _validatorScore;

    event UpdateValidatoScore(
        address indexed mining,
        ScoringFactor indexed factor,
        uint256 value
    );

    function initialize(address _owner) external initializer {
        if (_owner == address(0)) {
            revert ZeroAddress();
        }

        __Ownable_init(_owner);

        _setInitialScoringFactors();
    }

    function updateScore(address mining, ScoringFactor factor, uint256 value) public {
        emit UpdateValidatoScore(mining, factor, value);
    }

    function getValidatorScore(address mining) public view returns (uint256) {
        return _validatorScore[mining];
    }

    function _setInitialScoringFactors() private {
        _factors[ScoringFactor.StandByBonus] = DEFAULT_STAND_BY_FACTOR;
        _factors[ScoringFactor.NoKeyWritePenalty] = DEFAULT_NO_KEY_WRITE_FACTOR;
        _factors[ScoringFactor.BadPerformancePenalty] = DEFAULT_BAD_PERF_FACTOR;
    }
}
