//
//  PickLayoutTests.swift
//  RelenteTests
//
//  How many installers or drives fit as large items in a row, and when they become a grid.
//  Spec: specs/007-real-detection/spec.md ("Many installers or drives")
//

import Testing

@testable import Relente

struct PickLayoutTests {

    @Test func `up to four items make a row of large items`() {
        for count in 0...4 {
            #expect(PickLayout(itemCount: count) == .row)
        }
    }

    @Test func `five or more items make a grid of small items`() {
        for count in [5, 6, 10, 11, 40] {
            #expect(PickLayout(itemCount: count) == .grid)
        }
    }

    @Test func `a row uses large items and a grid small ones`() {
        #expect(PickLayout.row.itemSize == .regular)
        #expect(PickLayout.grid.itemSize == .compact)
    }

    @Test func `up and down move a whole grid row, and nothing in a row`() {
        #expect(PickLayout.grid.rowLength == 5)
        #expect(PickLayout.row.rowLength == nil)
    }
}
