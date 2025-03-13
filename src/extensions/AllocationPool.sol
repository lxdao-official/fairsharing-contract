// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../project/IProject.sol";
import "./IAllocationPool.sol";

import "forge-std/console2.sol";

contract AllocationPoolFactory is Ownable, IAllocationPoolFactory {
    // the template used to create allocation pool, low gas cost.
    address public allocationPoolTemplate;

    /**
     * @dev Emitted when allocation pool template changed.
     */
    event PoolTemplateChanged(address indexed operator, address indexed from, address indexed to);

    event PoolCreated(
        address indexed projectAddress,
        address indexed implementation,
        uint256 salt,
        address indexed creator
    );

    constructor(address _allocationTemplate) {
        require(_allocationTemplate != address(0), "Template cannot be zero address");
        allocationPoolTemplate = _allocationTemplate;
    }

    function updateTemplate(address _allocationPoolTemplate) external onlyOwner {
        // Fix: Store old value first for event emission
        address oldTemplate = allocationPoolTemplate;
        
        // Validate new template
        require(_allocationPoolTemplate != address(0), "Template cannot be zero address");
        
        // Update state only once
        allocationPoolTemplate = _allocationPoolTemplate;
        
        // Emit event if there was a change
        if (oldTemplate != _allocationPoolTemplate) {
            emit PoolTemplateChanged(_msgSender(), oldTemplate, _allocationPoolTemplate);
        }
    }

    function create(
        Allocation[] calldata allocations,
        ExtraParams calldata params
    ) external returns (address poolAddress) {
        // check allocations
        require(allocations.length > 0, "create arguments error");
        for (uint256 i = 0; i < allocations.length; i++) {
            Allocation memory allocation = allocations[i];
            uint256 amount = 0;
            require(
                allocation.addresses.length == allocation.tokenAmounts.length,
                "create arguments error"
            );
            for (uint256 j = 0; j < allocation.tokenAmounts.length; j++) {
                amount += allocation.tokenAmounts[j];
            }
            require(allocation.unClaimedAmount == amount, "create arguments error");
        }
        
        // Fix: Add validation for parameters
        require(params.timeToClaim > block.timestamp, "Claim time must be in the future");
        require(params.projectAddress != address(0), "Project address cannot be zero");

        address creator = _msgSender();

        poolAddress = Clones.cloneDeterministic(
            allocationPoolTemplate,
            keccak256(abi.encodePacked(creator, params.salt))
        );

        CreatPoolExtraParams memory initParams = CreatPoolExtraParams({
            owner: _msgSender(),
            projectAddress: params.projectAddress,
            creator: creator,
            depositor: params.depositor,
            timeToClaim: params.timeToClaim
        });
        IAllocationPoolTemplate(poolAddress).initialize(allocations, initParams);

        emit PoolCreated(poolAddress, allocationPoolTemplate, params.salt, creator);
    }

    function predictPoolAddress(address creator, uint256 salt) external view returns (address) {
        return
            Clones.predictDeterministicAddress(
                allocationPoolTemplate,
                keccak256(abi.encodePacked(creator, salt))
            );
    }
}

contract AllocationPoolTemplate is Context, ReentrancyGuard, IAllocationPoolTemplate {
    using SafeERC20 for IERC20;

    address public projectAddress;
    address public creator;
    address public depositor;
    uint256 public timeToClaim;
    // address -> bool
    mapping(address => bool) public claimStatus;
    Allocation[] public allocations;
    bool public isClaimed;
    
    // Fix: Add initialization guard
    bool private _initialized;

    event Initialized(address indexed creator, address indexed projectAddress, uint256 timeToClaim);
    event Deposited(address indexed from, address indexed token, uint256 amount);
    event Refunded(address indexed from, address indexed token, uint256 amount);
    event Claimed(address indexed from, address indexed token, uint256 amount);
    error RefundFailed();
    error ClaimFailed();
    error AlreadyInitialized();

    function initialize(
        Allocation[] calldata _allocations,
        CreatPoolExtraParams calldata params
    ) external {
        // Fix: Add initialization guard
        if (_initialized) {
            revert AlreadyInitialized();
        }
        
        // Fix: Add parameter validation
        require(params.projectAddress != address(0), "Project address cannot be zero");
        require(params.creator != address(0), "Creator cannot be zero address");
        require(params.timeToClaim > block.timestamp, "Claim time must be in the future");
        require(_allocations.length > 0, "Allocations cannot be empty");
        
        projectAddress = params.projectAddress;
        creator = params.creator;
        depositor = params.depositor;
        timeToClaim = params.timeToClaim;
        for (uint32 i = 0; i < _allocations.length; i++) {
            allocations.push(_allocations[i]);
        }
        isClaimed = false;
        
        // Mark as initialized
        _initialized = true;
        
        // Emit initialization event
        emit Initialized(params.creator, params.projectAddress, params.timeToClaim);
    }

    receive() external payable {}

    function deposit(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external payable nonReentrant {
        require(tokens.length == amounts.length, "deposit arguments error.");
        address from = _msgSender();
        
        // Fix: Validate total ETH amount
        uint256 totalETHRequired = 0;
        for (uint32 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                totalETHRequired += amounts[i];
            }
        }
        require(msg.value >= totalETHRequired, "Insufficient ETH sent");

        for (uint32 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                // ETH handling
                emit Deposited(from, address(0), amounts[i]);
            } else {
                // need approve first
                IERC20(tokens[i]).safeTransferFrom(from, address(this), amounts[i]);
                emit Deposited(from, tokens[i], amounts[i]);
            }
        }
    }

    function refund() external nonReentrant {
        address from = _msgSender();
        require(from == depositor, "caller is not depositor");

        // check time
        if (block.timestamp < timeToClaim) {
            // refund all
            _refund(from, true);
        } else {
            if (isClaimed) {
                // refund part
                _refund(from, false);
            } else {
                // refund all
                _refund(from, true);
            }
        }
    }

    function enforceRefundToken(address token) external nonReentrant {
        address to = _msgSender();
        require(to == depositor, "caller is not depositor");
        //        for (uint32 i = 0; i < allocations.length; i++) {
        //            Allocation memory allocation = allocations[i];
        //            require(token != allocation.token, "just can refund unspecified token.");
        //        }
        if (token == address(0)) {
            uint256 balance = address(this).balance;
            if (balance > 0) {
                // Fix: Store the amount to refund before making the external call
                uint256 amountToRefund = balance;
                
                (bool success, ) = to.call{value: amountToRefund}("");
                if (!success) {
                    revert RefundFailed();
                }
                emit Refunded(to, token, amountToRefund);
            }
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                // Fix: Store the amount to refund before making the external call
                uint256 amountToRefund = balance;
                
                IERC20(token).safeTransfer(to, amountToRefund);
                emit Refunded(to, token, amountToRefund);
            }
        }
    }

    function _assetsAreRight() internal view returns (bool) {
        for (uint32 i = 0; i < allocations.length; i++) {
            Allocation memory allocation = allocations[i];
            address token = allocation.token;
            uint256 totalAmount = 0;
            // distribute every wallet
            for (uint32 j = 0; j < allocation.tokenAmounts.length; j++) {
                totalAmount += allocation.tokenAmounts[j];
            }
            if (token == address(0)) {
                if (totalAmount != address(this).balance) {
                    return false;
                }
            } else {
                if (totalAmount != IERC20(token).balanceOf(address(this))) {
                    return false;
                }
            }
        }
        return true;
    }

    function _refund(address to, bool isAll) internal {
        for (uint32 i = 0; i < allocations.length; i++) {
            address token = allocations[i].token;
            if (token == address(0)) {
                uint256 canRefundAmount = address(this).balance;
                if (canRefundAmount > 0) {
                    if (!isAll) {
                        uint256 unClaimedAmount = allocations[i].unClaimedAmount;
                        canRefundAmount -= unClaimedAmount;
                    }
                    if (canRefundAmount > 0) {
                        // Fix: Store the amount to refund before making the external call
                        uint256 amountToRefund = canRefundAmount;
                        
                        (bool success, ) = to.call{value: amountToRefund}("");
                        if (!success) {
                            revert RefundFailed();
                        }
                        emit Refunded(to, token, amountToRefund);
                    }
                }
            } else {
                uint256 canRefundAmount = IERC20(token).balanceOf(address(this));
                if (canRefundAmount > 0) {
                    if (!isAll) {
                        uint256 unClaimedAmount = allocations[i].unClaimedAmount;
                        canRefundAmount -= unClaimedAmount;
                    }
                    if (canRefundAmount > 0) {
                        // Fix: Store the amount to refund before making the external call
                        uint256 amountToRefund = canRefundAmount;
                        
                        IERC20(token).safeTransfer(to, amountToRefund);
                        emit Refunded(to, token, amountToRefund);
                    }
                }
            }
        }
    }

    function claim() external nonReentrant {
        require(block.timestamp >= timeToClaim, "the claim time has not arrived yet.");

        address from = _msgSender();
        require(claimStatus[from] == false, "you are already claimed.");
        // check
        if (!isClaimed) {
            require(_assetsAreRight(), "the contract's tokens balance don't match allocations");
        }
        // claim
        for (uint32 i = 0; i < allocations.length; i++) {
            Allocation storage allocation = allocations[i];
            address token = allocation.token;

            for (uint32 j = 0; j < allocation.addresses.length; j++) {
                address to = allocation.addresses[j];
                if (to == from) {
                    uint256 amount = allocation.tokenAmounts[j];
                    if (token == address(0)) {
                        (bool success, ) = to.call{value: amount}("");
                        if (!success) {
                            revert ClaimFailed();
                        }
                        // record unclaimed token amount
                        allocation.unClaimedAmount -= amount;

                        emit Claimed(to, token, amount);
                    } else {
                        IERC20(token).safeTransfer(to, amount);
                        // record unclaimed token amount
                        allocation.unClaimedAmount -= amount;

                        emit Claimed(to, token, amount);
                    }
                }
            }
        }
        claimStatus[from] = true;
        if (!isClaimed) {
            isClaimed = true;
        }
    }
}
