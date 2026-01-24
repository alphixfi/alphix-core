// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {BaseAlphix4626WrapperSky} from "../../BaseAlphix4626WrapperSky.t.sol";
import {IAlphix4626WrapperSky} from "../../../../../src/wrappers/sky/interfaces/IAlphix4626WrapperSky.sol";

/**
 * @title CircuitBreakerTest
 * @author Alphix
 * @notice Unit tests for the rate circuit breaker mechanism.
 * @dev Tests the 5% bidirectional rate change limit that reverts on breach.
 *      The circuit breaker protects against oracle manipulation by blocking
 *      any transaction that would process a rate change exceeding 5%.
 */
contract CircuitBreakerTest is BaseAlphix4626WrapperSky {
    /// @notice Event emitted when circuit breaker triggers
    event CircuitBreakerTriggered(uint256 lastRate, uint256 currentRate, uint256 changeBps);

    /* POSITIVE DIRECTION TESTS */

    /**
     * @notice Tests that small positive rate changes (4%) are allowed.
     */
    function test_circuitBreaker_allowsSmallPositiveChange() public {
        // First deposit to establish state
        _depositAsHook(10_000e18, alphixHook);

        // 4% yield should pass
        _simulateYieldPercent(4);

        // Trigger accrual via deposit (should succeed)
        _depositAsHook(100e18, alphixHook);

        _assertSolvent();
    }

    /**
     * @notice Tests that exactly 5% positive rate change is allowed (threshold is <=).
     */
    function test_circuitBreaker_exactThreshold_positive_passes() public {
        _depositAsHook(10_000e18, alphixHook);

        // Exactly 5% yield should pass
        _simulateYieldPercent(5);

        // Trigger accrual via deposit
        _depositAsHook(100e18, alphixHook);

        _assertSolvent();
    }

    /**
     * @notice Tests that large positive rate changes (6%) trigger the circuit breaker and revert.
     */
    function test_circuitBreaker_triggersOnLargePositiveChange() public {
        _depositAsHook(10_000e18, alphixHook);

        // 6% yield should trigger circuit breaker
        _simulateYieldPercent(6);

        // Attempt to trigger accrual via deposit - should revert
        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert();
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();
    }

    /**
     * @notice Tests that 10% positive rate change reverts.
     */
    function test_circuitBreaker_largePositiveChange_reverts() public {
        _depositAsHook(10_000e18, alphixHook);

        // 10% yield should trigger circuit breaker
        _simulateYieldPercent(10);

        // Attempt operation that triggers accrual - should revert
        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert();
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();
    }

    /**
     * @notice Tests that circuit breaker reverts with ExcessiveRateChange error.
     */
    function test_circuitBreaker_positiveChange_revertsWithError() public {
        _depositAsHook(10_000e18, alphixHook);

        uint256 lastRate = _getCurrentRate();

        // 10% yield
        _simulateYieldPercent(10);
        uint256 currentRate = _getCurrentRate();
        uint256 expectedChangeBps = ((currentRate - lastRate) * 10_000) / lastRate;

        // Expect specific revert
        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAlphix4626WrapperSky.ExcessiveRateChange.selector, lastRate, currentRate, expectedChangeBps
            )
        );
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();
    }

    /* NEGATIVE DIRECTION TESTS */

    /**
     * @notice Tests that small negative rate changes (4%) are allowed.
     */
    function test_circuitBreaker_allowsSmallNegativeChange() public {
        _depositAsHook(10_000e18, alphixHook);

        // 4% slash should pass
        _simulateSlashPercent(4);

        // Trigger accrual via deposit
        _depositAsHook(100e18, alphixHook);

        _assertSolvent();
    }

    /**
     * @notice Tests that exactly 5% negative rate change is allowed.
     */
    function test_circuitBreaker_exactThreshold_negative_passes() public {
        _depositAsHook(10_000e18, alphixHook);

        // Exactly 5% slash should pass
        _simulateSlashPercent(5);

        // Trigger accrual via deposit
        _depositAsHook(100e18, alphixHook);

        _assertSolvent();
    }

    /**
     * @notice Tests that large negative rate changes (6%) trigger the circuit breaker.
     */
    function test_circuitBreaker_triggersOnLargeNegativeChange() public {
        _depositAsHook(10_000e18, alphixHook);

        // 6% slash should trigger circuit breaker
        _simulateSlashPercent(6);

        // Attempt to trigger accrual via deposit - should revert
        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert();
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();
    }

    /**
     * @notice Tests that 10% negative rate change reverts.
     */
    function test_circuitBreaker_largeNegativeChange_reverts() public {
        _depositAsHook(10_000e18, alphixHook);

        // 10% slash should trigger circuit breaker
        _simulateSlashPercent(10);

        // Attempt operation that triggers accrual - should revert
        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert();
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();
    }

    /**
     * @notice Tests that circuit breaker reverts with ExcessiveRateChange on negative breach.
     */
    function test_circuitBreaker_negativeChange_revertsWithError() public {
        _depositAsHook(10_000e18, alphixHook);

        uint256 lastRate = _getCurrentRate();

        // 10% slash
        _simulateSlashPercent(10);
        uint256 currentRate = _getCurrentRate();
        uint256 expectedChangeBps = ((lastRate - currentRate) * 10_000) / lastRate;

        // Expect specific revert
        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAlphix4626WrapperSky.ExcessiveRateChange.selector, lastRate, currentRate, expectedChangeBps
            )
        );
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();
    }

    /* EDGE CASE TESTS */

    /**
     * @notice Tests that first user deposit works normally.
     * @dev On deployment, lastRate is set to initial rate, so first accrual already has a baseline.
     */
    function test_circuitBreaker_firstUserDeposit_works() public {
        // First user deposit should work
        _depositAsHook(1000e18, alphixHook);
    }

    /**
     * @notice Tests that multiple small changes are allowed sequentially.
     * @dev Each change is checked independently against the updated baseline.
     */
    function test_circuitBreaker_loopedSmallChanges_allowed() public {
        _depositAsHook(10_000e18, alphixHook);

        // Multiple 4% changes should all pass when accrual triggers between each
        for (uint256 i = 0; i < 5; i++) {
            _simulateYieldPercent(4);

            // Trigger accrual to update lastRate
            vm.prank(owner);
            wrapper.setFee(DEFAULT_FEE);
        }

        _assertSolvent();
    }

    /**
     * @notice Tests that cumulative small changes that compound to >5% still work.
     * @dev Because each change is checked independently after accrual updates lastRate.
     */
    function test_circuitBreaker_cumulativeChanges_checkPerAccrual() public {
        _depositAsHook(10_000e18, alphixHook);

        uint256 initialRate = _getCurrentRate();

        // Do 5 cycles of 4% yield with accrual between each
        for (uint256 i = 0; i < 5; i++) {
            _simulateYieldPercent(4);
            vm.prank(owner);
            wrapper.setFee(DEFAULT_FEE);
        }

        uint256 finalRate = _getCurrentRate();

        // Total rate increase is roughly (1.04)^5 - 1 ≈ 21.7%
        assertGt(finalRate, initialRate * 120 / 100, "Rate should have increased >20%");

        _assertSolvent();
    }

    /**
     * @notice Tests that operations work after rate normalizes following a failed attempt.
     */
    function test_circuitBreaker_operationsWorkAfterRateNormalizes() public {
        _depositAsHook(10_000e18, alphixHook);

        // Trigger circuit breaker with 10% change - reverts
        _simulateYieldPercent(10);

        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert();
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();

        // Reset rate to something reasonable
        _setRate(INITIAL_RATE);

        // Operations should work
        _depositAsHook(100e18, alphixHook);
    }

    /**
     * @notice Tests that rate unchanged does not trigger circuit breaker.
     */
    function test_circuitBreaker_rateUnchanged_noop() public {
        _depositAsHook(10_000e18, alphixHook);

        // Don't change rate at all

        // Deposit should work
        _depositAsHook(100e18, alphixHook);
    }

    /**
     * @notice Tests circuit breaker reverts on withdraw operation.
     */
    function test_circuitBreaker_triggersOnWithdraw() public {
        _depositAsHook(10_000e18, alphixHook);

        // 10% yield should trigger circuit breaker
        _simulateYieldPercent(10);

        // Attempt withdraw - should revert
        vm.prank(alphixHook);
        vm.expectRevert();
        wrapper.withdraw(1000e18, alphixHook, alphixHook);
    }

    /**
     * @notice Tests circuit breaker reverts on redeem operation.
     */
    function test_circuitBreaker_triggersOnRedeem() public {
        _depositAsHook(10_000e18, alphixHook);

        // 10% slash should trigger circuit breaker
        _simulateSlashPercent(10);

        // Attempt redeem - should revert
        uint256 shares = wrapper.balanceOf(alphixHook);
        vm.prank(alphixHook);
        vm.expectRevert();
        wrapper.redeem(shares / 2, alphixHook, alphixHook);
    }

    /**
     * @notice Tests circuit breaker reverts on fee collection.
     */
    function test_circuitBreaker_triggersOnCollectFees() public {
        _depositAsHook(10_000e18, alphixHook);

        // Generate some fees first
        _simulateYieldPercent(5);
        vm.prank(owner);
        wrapper.setFee(DEFAULT_FEE); // Trigger accrual to generate fees

        // Now simulate excessive rate change
        _simulateYieldPercent(10);

        // Attempt fee collection - should revert
        vm.prank(owner);
        vm.expectRevert();
        wrapper.collectFees();
    }

    /**
     * @notice Tests that setFee also triggers circuit breaker revert.
     */
    function test_circuitBreaker_triggersOnSetFee() public {
        _depositAsHook(10_000e18, alphixHook);

        // 10% yield should trigger circuit breaker
        _simulateYieldPercent(10);

        // Attempt to change fee (triggers accrual) - should revert
        vm.prank(owner);
        vm.expectRevert();
        wrapper.setFee(200_000);
    }

    /* FUZZ TESTS FOR CIRCUIT BREAKER */

    /**
     * @notice Fuzz test that changes within threshold always pass.
     */
    function testFuzz_circuitBreaker_withinThreshold_passes(uint256 changePercent) public {
        changePercent = bound(changePercent, 1, 5);

        _depositAsHook(10_000e18, alphixHook);

        _simulateYieldPercent(changePercent);

        // Should succeed
        _depositAsHook(100e18, alphixHook);
    }

    /**
     * @notice Fuzz test that changes exceeding threshold always revert.
     */
    function testFuzz_circuitBreaker_exceedsThreshold_reverts(uint256 changePercent) public {
        changePercent = bound(changePercent, 6, 50);

        _depositAsHook(10_000e18, alphixHook);

        _simulateYieldPercent(changePercent);

        // Should revert
        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert();
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test negative changes within threshold pass.
     */
    function testFuzz_circuitBreaker_negativeWithinThreshold_passes(uint256 slashPercent) public {
        slashPercent = bound(slashPercent, 1, 5);

        _depositAsHook(10_000e18, alphixHook);

        _simulateSlashPercent(slashPercent);

        // Should succeed
        _depositAsHook(100e18, alphixHook);
    }

    /**
     * @notice Fuzz test negative changes exceeding threshold revert.
     */
    function testFuzz_circuitBreaker_negativeExceedsThreshold_reverts(uint256 slashPercent) public {
        slashPercent = bound(slashPercent, 6, 50);

        _depositAsHook(10_000e18, alphixHook);

        _simulateSlashPercent(slashPercent);

        // Should revert
        usds.mint(alphixHook, 100e18);
        vm.startPrank(alphixHook);
        usds.approve(address(wrapper), 100e18);
        vm.expectRevert();
        wrapper.deposit(100e18, alphixHook);
        vm.stopPrank();
    }

    /**
     * @notice Fuzz test boundary: exactly 5% always passes.
     */
    function testFuzz_circuitBreaker_exactlyFivePercent_passes(bool isPositive) public {
        _depositAsHook(10_000e18, alphixHook);

        if (isPositive) {
            _simulateYieldPercent(5);
        } else {
            _simulateSlashPercent(5);
        }

        // Should succeed at exactly 5%
        _depositAsHook(100e18, alphixHook);
    }
}
