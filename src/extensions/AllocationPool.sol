// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../project/IProject.sol";
import "./IAllocationPool.sol";

contract AllocationPoolFactory is Ownable, IAllocationPoolFactory {
    // Created pool index, default is 0.
    uint256 private index;

    // the template used to create allocation pool, low gas cost.
    address public allocationPoolTemplate;

    /**
     * @dev Emitted when allocation pool template changed.
     */
    event ProjectTemplateChanged(
        address indexed operator,
        address indexed from,
        address indexed to
    );

    constructor(address _allocationTemplate) {
        allocationPoolTemplate = _allocationTemplate;
    }

    function updateTemplate(address _allocationPoolTemplate) external onlyOwner {
        allocationPoolTemplate = _allocationPoolTemplate;

        if (_allocationPoolTemplate != allocationPoolTemplate) {
            emit ProjectTemplateChanged(
                _msgSender(),
                allocationPoolTemplate,
                _allocationPoolTemplate
            );
            allocationPoolTemplate = _allocationPoolTemplate;
        }
    }

    function create(
        AllocationPoolInitializeParams calldata param,
        Allocation[] calldata allocations
    ) external returns (address) {
        address poolAddress = Clones.cloneDeterministic(
            allocationPoolTemplate,
            keccak256(abi.encodePacked(index))
        );

        AllocationPoolInitializeParams memory initParams = AllocationPoolInitializeParams({
            projectAddress: param.projectAddress,
            creator: param.creator,
            depositor: param.depositor,
            timeToClaim: param.timeToClaim
        });
        IAllocationPoolTemplate(poolAddress).initialize(initParams, allocations);

        index++;

        // todo:event

        return poolAddress;
    }
}

contract AllocationPoolTemplate is Context, ReentrancyGuard, IAllocationPoolTemplate {
    using SafeERC20 for IERC20;

    address public creator;
    address public depositor;
    uint256 public timeToClaim;
    mapping(address => bool) public claims;
    Allocation[] public allocations;
    bool public isClaimNeedCheck;

    error RefundFailed();

    function initialize(
        AllocationPoolInitializeParams calldata param,
        Allocation[] calldata _allocations
    ) external {
        creator = param.creator;
        depositor = param.depositor;
        timeToClaim = param.timeToClaim;
        for (uint32 i = 0; i < _allocations.length; i++) {
            allocations.push(_allocations[i]);
        }
        isClaimNeedCheck = true;
    }

    receive() external payable {}

    function deposit(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external payable nonReentrant {
        require(tokens.length == amounts.length, "deposit arguments error.");
        address from = _msgSender();
        for (uint32 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(from, address(this), amounts[i]);
        }
        // todo:event
    }

    function refund() external nonReentrant {
        address from = _msgSender();
        require(from == depositor, "caller is not depositor");

        // check time
        if (block.timestamp < timeToClaim) {
            // refund
            _refund(from);
        } else {
            // check assets
            if (_assetsAreRight()) {
                revert("No refunds are allowed during claim time.");
            } else {
                // refund
                _refund(from);
            }
        }
        // todo:event
    }

    function _assetsAreRight() internal returns (bool) {
        for (uint32 i = 0; i < allocations.length; i++) {
            Allocation memory allocation = allocations[i];
            address token = allocation.token;
            uint256 totalAmount = 0;
            // distribute every wallet
            for (uint32 j = 0; j < allocation.amounts.length; j++) {
                totalAmount += allocation.amounts[j];
            }
            if (token == address(0)) {
                if (totalAmount == address(this).balance) {
                    return false;
                }
            } else {
                if (totalAmount == IERC20(token).balanceOf(address(this))) {
                    return false;
                }
            }
        }
        return true;
    }

    function _refund(address to) internal {
        for (uint32 i = 0; i < allocations.length; i++) {
            address token = allocations[i].token;
            if (token == address(0)) {
                uint256 balance = address(this).balance;
                (bool success, ) = to.call{value: balance}("");
                if (!success) {
                    revert RefundFailed();
                }
            } else {
                uint256 balance = IERC20(token).balanceOf(address(this));
                IERC20(token).safeTransferFrom(address(this), to, balance);
            }
        }
        // todo:event
    }

    function claim() external nonReentrant {
        require(block.timestamp >= timeToClaim, "the claim time has not arrived yet.");

        address from = _msgSender();
        require(claims[from], "you are already claimed.");
        // check
        if (isClaimNeedCheck) {
            require(_assetsAreRight(), "the contract's tokens balance don't match allocations");
        }
        // claim
        for (uint32 i = 0; i < allocations.length; i++) {
            Allocation memory allocation = allocations[i];
            address token = allocation.token;

            // distribute every wallet
            for (uint32 j = 0; j < allocation.addresses.length; j++) {
                address to = allocation.addresses[j];
                uint256 amount = allocation.amounts[j];
                if (token == address(0)) {
                    (bool success, ) = to.call{value: amount}("");
                    if (!success) {
                        revert RefundFailed();
                    }
                } else {
                    IERC20(token).safeTransferFrom(address(this), to, amount);
                }
            }
        }
        claims[from] = true;
        if (isClaimNeedCheck) {
            isClaimNeedCheck = false;
        }

        // todo:event
    }
}
