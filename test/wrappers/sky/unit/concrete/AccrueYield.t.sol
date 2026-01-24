// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {BaseAlphix4626WrapperSky} from "../../BaseAlphix4626WrapperSky.t.sol";

/**
 * @title AccrueYieldTest
 * @author Alphix
 * @notice Unit tests for the Alphix4626WrapperSky yield accrual mechanism.
 * @dev Tests the _accrueYield internal function through public interfaces (deposit, setFee).
 *      Yield is tracked via rate provider (sUSDS/USDS rate changes).
 */
contract AccrueYieldTest is BaseAlphix4626WrapperSky {
    /**
     * @notice Tests that yield accrual emits event when rate increases.
     */
    function test_accrueYield_emitsEvent() public {
        _depositAsHook(1000e18, alphixHook);

        // Simulate 10% yield via rate increase
        _simulateYieldPercent(5);

        // Trigger accrual via setFee - expect YieldAccrued to be emitted
        vm.recordLogs();

        vm.prank(owner);
        wrapper.setFee(DEFAULT_FEE);

        // Check that YieldAccrued was emitted
        bool yieldAccruedEmitted = false;
        bytes32 yieldAccruedSelector = keccak256("YieldAccrued(uint256,uint256,uint256)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == yieldAccruedSelector) {
                yieldAccruedEmitted = true;
                break;
            }
        }
        assertTrue(yieldAccruedEmitted, "YieldAccrued event not emitted");
    }

    /**
     * @notice Tests that yield accrual is triggered on deposit.
     */
    function test_accrueYield_triggeredOnDeposit() public {
        _depositAsHook(1000e18, alphixHook);

        // Simulate yield
        _simulateYieldPercent(5);

        // Record logs during deposit
        vm.recordLogs();
        _depositAsHook(500e18, alphixHook);

        // Check that YieldAccrued was emitted
        bool yieldAccruedEmitted = false;
        bytes32 yieldAccruedSelector = keccak256("YieldAccrued(uint256,uint256,uint256)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == yieldAccruedSelector) {
                yieldAccruedEmitted = true;
                break;
            }
        }
        assertTrue(yieldAccruedEmitted, "YieldAccrued event not emitted on deposit");
    }

    /**
     * @notice Tests that yield accrual is triggered on setFee.
     */
    function test_accrueYield_triggeredOnSetFee() public {
        _depositAsHook(1000e18, alphixHook);

        // Simulate yield
        _simulateYieldPercent(5);

        // Record logs during setFee
        vm.recordLogs();

        vm.prank(owner);
        wrapper.setFee(50_000);

        // Check that YieldAccrued was emitted
        bool yieldAccruedEmitted = false;
        bytes32 yieldAccruedSelector = keccak256("YieldAccrued(uint256,uint256,uint256)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == yieldAccruedSelector) {
                yieldAccruedEmitted = true;
                break;
            }
        }
        assertTrue(yieldAccruedEmitted, "YieldAccrued event not emitted on setFee");
    }

    /**
     * @notice Tests that no event is emitted when no yield (rate unchanged).
     */
    function test_accrueYield_noYield_noEvent() public {
        _depositAsHook(1000e18, alphixHook);

        // No yield simulation, just trigger accrual
        // Should not emit YieldAccrued event since no rate change

        vm.recordLogs();
        _depositAsHook(500e18, alphixHook);

        // Check that YieldAccrued was NOT emitted
        bool yieldAccruedEmitted = false;
        bytes32 yieldAccruedSelector = keccak256("YieldAccrued(uint256,uint256,uint256)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == yieldAccruedSelector) {
                yieldAccruedEmitted = true;
                break;
            }
        }
        assertFalse(yieldAccruedEmitted, "YieldAccrued event should not be emitted when no yield");
    }

    /**
     * @notice Tests yield accrual with zero fee.
     */
    function test_accrueYield_zeroFee_noFeesAccumulated() public {
        // Set fee to 0
        vm.prank(owner);
        wrapper.setFee(0);

        _depositAsHook(1000e18, alphixHook);

        // Simulate 10% yield
        _simulateYieldPercent(5);

        // Trigger accrual - with 0% fee, feeAmount should be 0
        vm.recordLogs();
        _depositAsHook(500e18, alphixHook);

        // Check that YieldAccrued was emitted with 0 fee
        bytes32 yieldAccruedSelector = keccak256("YieldAccrued(uint256,uint256,uint256)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == yieldAccruedSelector) {
                // Decode event data - (yieldAmount, feeAmount, newRate)
                (uint256 yieldAmount, uint256 feeAmount,) = abi.decode(entries[i].data, (uint256, uint256, uint256));
                assertGt(yieldAmount, 0, "Yield should be greater than 0");
                assertEq(feeAmount, 0, "Fee should be 0 with 0% fee");
                return;
            }
        }
        fail("YieldAccrued event not emitted");
    }

    /**
     * @notice Tests yield accrual with max fee.
     */
    function test_accrueYield_maxFee() public {
        // Set fee to 100%
        vm.prank(owner);
        wrapper.setFee(MAX_FEE);

        _depositAsHook(1000e18, alphixHook);

        // Simulate 10% yield
        _simulateYieldPercent(5);

        // Trigger accrual - with 100% fee, all yield goes to fees
        vm.recordLogs();
        _depositAsHook(500e18, alphixHook);

        // Check that YieldAccrued was emitted
        bytes32 yieldAccruedSelector = keccak256("YieldAccrued(uint256,uint256,uint256)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == yieldAccruedSelector) {
                // Decode event data - (yieldAmount, feeAmount, newRate)
                (uint256 yieldAmount, uint256 feeAmount,) = abi.decode(entries[i].data, (uint256, uint256, uint256));
                assertGt(yieldAmount, 0, "Yield should be greater than 0");
                // Fee should be significant (but due to sUSDS conversion, may not be exactly equal)
                assertGt(feeAmount, 0, "Fee should be positive with 100% fee");
                return;
            }
        }
        fail("YieldAccrued event not emitted");
    }

    /**
     * @notice Tests multiple yield accruals.
     */
    function test_accrueYield_multipleAccruals() public {
        _depositAsHook(1000e18, alphixHook);

        // First yield
        _simulateYieldPercent(5);

        vm.recordLogs();
        _depositAsHook(500e18, alphixHook);

        bool firstYieldEmitted = false;
        bytes32 yieldAccruedSelector = keccak256("YieldAccrued(uint256,uint256,uint256)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == yieldAccruedSelector) {
                firstYieldEmitted = true;
                break;
            }
        }
        assertTrue(firstYieldEmitted, "First YieldAccrued event not emitted");

        // Second yield
        _simulateYieldPercent(5);

        vm.recordLogs();
        _depositAsHook(250e18, alphixHook);

        bool secondYieldEmitted = false;
        entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == yieldAccruedSelector) {
                secondYieldEmitted = true;
                break;
            }
        }
        assertTrue(secondYieldEmitted, "Second YieldAccrued event not emitted");
    }

    /**
     * @notice Tests that solvency is maintained after yield accrual.
     */
    function test_accrueYield_maintainsSolvency() public {
        _depositAsHook(1000e18, alphixHook);

        // Simulate yield
        _simulateYieldPercent(5);

        // Trigger accrual
        _depositAsHook(500e18, alphixHook);

        _assertSolvent();
    }

    /**
     * @notice Tests that lastRate is updated after yield accrual.
     */
    function test_accrueYield_updatesLastRate() public {
        _depositAsHook(1000e18, alphixHook);

        uint256 lastRateBefore = wrapper.getLastRate();

        // Simulate yield
        _simulateYieldPercent(5);

        // Trigger accrual
        vm.prank(owner);
        wrapper.setFee(DEFAULT_FEE);

        uint256 lastRateAfter = wrapper.getLastRate();
        assertGt(lastRateAfter, lastRateBefore, "Last rate should increase after yield");
    }
}
