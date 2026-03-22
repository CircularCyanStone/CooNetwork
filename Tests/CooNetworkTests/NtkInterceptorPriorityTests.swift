//
//  NtkInterceptorPriorityTests.swift
//  CooNetworkTests
//

import Testing
import Foundation
@testable import CooNetwork

struct NtkInterceptorPriorityTests {

    // MARK: - Tier 比较

    @Test
    func outerTierGreaterThanStandard() {
        let outer = NtkInterceptorPriority.coreOuterHighest
        let standard = NtkInterceptorPriority.high
        #expect(outer > standard)
    }

    @Test
    func standardTierGreaterThanInner() {
        let standard = NtkInterceptorPriority.low
        let inner = NtkInterceptorPriority.coreInnerLow
        #expect(standard > inner)
    }

    @Test
    func outerTierGreaterThanInner() {
        let outer = NtkInterceptorPriority.coreOuterHighest
        let inner = NtkInterceptorPriority.coreInnerHigh
        #expect(outer > inner)
    }

    @Test
    func sameTierComparesValue() {
        let highStandard = NtkInterceptorPriority.high      // standard, 1000
        let medStandard  = NtkInterceptorPriority.medium    // standard, 750
        #expect(highStandard > medStandard)
    }

    // MARK: - priority() 工厂方法

    @Test
    func priorityFactoryCreatesStandardTier() {
        let p = NtkInterceptorPriority.priority(500)
        // Must be less than any inner tier (inner.low = 250 but inner tier is lower)
        // Must be greater than inner tier constants
        let inner = NtkInterceptorPriority.coreInnerHigh
        #expect(p > inner)  // standard tier always > inner tier
    }

    @Test
    func priorityFactoryClampedAt1000() {
        let p = NtkInterceptorPriority.priority(9999)
        let high = NtkInterceptorPriority.high
        #expect(p == high)
    }

    @Test
    func priorityFactoryClampedAtZero() {
        let p = NtkInterceptorPriority.priority(-100)
        let expected = NtkInterceptorPriority.priority(0)
        #expect(p == expected)
    }

    // MARK: - 算术运算符

    @Test
    func additionPreservesTier() {
        let p = NtkInterceptorPriority.medium  // standard, 750
        let result = p + 100
        let outerHigh = NtkInterceptorPriority.coreOuterHighest
        // result is still standard tier, so must be < outer tier
        #expect(result < outerHigh)
        #expect(result > NtkInterceptorPriority.coreInnerHigh)  // still above inner
    }

    @Test
    func additionClampsAt1000() {
        let p = NtkInterceptorPriority.high  // standard, 1000
        let result = p + 500
        #expect(result == NtkInterceptorPriority.high)
    }

    @Test
    func subtractionPreservesTier() {
        let inner = NtkInterceptorPriority.coreInnerHigh  // inner, 750
        let result = inner - 500  // inner, 250
        let standard = NtkInterceptorPriority.low  // standard, 250
        // same value, different tier → inner < standard
        #expect(result < standard)
    }

    @Test
    func subtractionClampsAtZero() {
        let p = NtkInterceptorPriority.low  // standard, 250
        let result = p - 9999
        let expected = NtkInterceptorPriority.priority(0)
        #expect(result == expected)
    }

    @Test
    func additionWithNegativeRhsClampsAtZero() {
        let p = NtkInterceptorPriority.low  // standard, 250
        let result = p + (-9999)
        let expected = NtkInterceptorPriority.priority(0)
        #expect(result == expected)
    }

    @Test
    func subtractionWithNegativeRhsClampsAt1000() {
        let p = NtkInterceptorPriority.medium  // standard, 750
        let result = p - (-9999)  // 750 - (-9999) = 10749, clamp to 1000
        #expect(result == NtkInterceptorPriority.high)
    }

    // MARK: - init() 默认值

    @Test
    func defaultInitIsMedium() {
        let p = NtkInterceptorPriority()
        #expect(p == NtkInterceptorPriority.medium)
    }
}
