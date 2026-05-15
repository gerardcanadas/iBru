import Testing
import Foundation
@testable import iBru

@Suite
struct WHOGrowthDataTests {

    // MARK: - Table completeness

    @Test func boysWeightTableHas61Rows() {
        let table = WHOGrowthData.weightPoints(sex: .male)
        #expect(table.count == 61)
    }

    @Test func girlsWeightTableHas61Rows() {
        let table = WHOGrowthData.weightPoints(sex: .female)
        #expect(table.count == 61)
    }

    @Test func boysHeightTableHas61Rows() {
        #expect(WHOGrowthData.heightPoints(sex: .male).count == 61)
    }

    @Test func girlsHeightTableHas61Rows() {
        #expect(WHOGrowthData.heightPoints(sex: .female).count == 61)
    }

    @Test func boysHeadTableHas61Rows() {
        #expect(WHOGrowthData.headPoints(sex: .male).count == 61)
    }

    @Test func girlsHeadTableHas61Rows() {
        #expect(WHOGrowthData.headPoints(sex: .female).count == 61)
    }

    // MARK: - Age indexing

    @Test func ageMonthsAreSequential() {
        let table = WHOGrowthData.weightPoints(sex: .male)
        for (i, pt) in table.enumerated() {
            #expect(pt.ageMonths == Double(i))
        }
    }

    // MARK: - Percentile ordering

    @Test func boysWeightP3LessThanP50LessThanP97() {
        for pt in WHOGrowthData.weightPoints(sex: .male) {
            #expect(pt.p3 < pt.p50 && pt.p50 < pt.p97,
                    "Failed at month \(pt.ageMonths): p3=\(pt.p3) p50=\(pt.p50) p97=\(pt.p97)")
        }
    }

    @Test func girlsWeightP3LessThanP50LessThanP97() {
        for pt in WHOGrowthData.weightPoints(sex: .female) {
            #expect(pt.p3 < pt.p50 && pt.p50 < pt.p97)
        }
    }

    @Test func boysHeightP3LessThanP50LessThanP97() {
        for pt in WHOGrowthData.heightPoints(sex: .male) {
            #expect(pt.p3 < pt.p50 && pt.p50 < pt.p97)
        }
    }

    @Test func girlsHeightP3LessThanP50LessThanP97() {
        for pt in WHOGrowthData.heightPoints(sex: .female) {
            #expect(pt.p3 < pt.p50 && pt.p50 < pt.p97)
        }
    }

    @Test func boysHeadP3LessThanP50LessThanP97() {
        for pt in WHOGrowthData.headPoints(sex: .male) {
            #expect(pt.p3 < pt.p50 && pt.p50 < pt.p97)
        }
    }

    @Test func girlsHeadP3LessThanP50LessThanP97() {
        for pt in WHOGrowthData.headPoints(sex: .female) {
            #expect(pt.p3 < pt.p50 && pt.p50 < pt.p97)
        }
    }

    // MARK: - Interpolation

    @Test func interpolationAtIntegerMonthReturnsExactValue() {
        let table = WHOGrowthData.weightPoints(sex: .male)
        let pt = WHOGrowthData.interpolated(ageMonths: 12.0, from: table)
        #expect(pt != nil)
        #expect(pt!.p50 == table[12].p50)
    }

    @Test func interpolationAtHalfMonthReturnsBetweenNeighbors() {
        let table = WHOGrowthData.weightPoints(sex: .male)
        let pt = WHOGrowthData.interpolated(ageMonths: 6.5, from: table)
        #expect(pt != nil)
        #expect(pt!.p50 > table[6].p50 && pt!.p50 < table[7].p50)
        #expect(pt!.p3  > table[6].p3  && pt!.p3  < table[7].p3)
        #expect(pt!.p97 > table[6].p97 && pt!.p97 < table[7].p97)
    }

    @Test func interpolationBeyond60MonthsReturnsNil() {
        let table = WHOGrowthData.weightPoints(sex: .male)
        let pt = WHOGrowthData.interpolated(ageMonths: 61.0, from: table)
        #expect(pt == nil)
    }

    @Test func interpolationAtZeroMonthsReturnsFirstRow() {
        let table = WHOGrowthData.weightPoints(sex: .female)
        let pt = WHOGrowthData.interpolated(ageMonths: 0.0, from: table)
        #expect(pt != nil)
        #expect(pt!.p50 == table[0].p50)
    }

    // MARK: - Physiological sanity checks

    @Test func boysWeighMoreThanGirlsAtBirth() {
        let boysP50 = WHOGrowthData.weightPoints(sex: .male)[0].p50
        let girlsP50 = WHOGrowthData.weightPoints(sex: .female)[0].p50
        #expect(boysP50 > girlsP50)
    }

    @Test func weightIncreasesWithAge() {
        let table = WHOGrowthData.weightPoints(sex: .male)
        for i in 1 ..< table.count {
            #expect(table[i].p50 >= table[i - 1].p50,
                    "P50 decreased at month \(i)")
        }
    }

    @Test func heightIncreasesWithAge() {
        let table = WHOGrowthData.heightPoints(sex: .male)
        for i in 1 ..< table.count {
            #expect(table[i].p50 >= table[i - 1].p50,
                    "P50 height decreased at month \(i)")
        }
    }
}
