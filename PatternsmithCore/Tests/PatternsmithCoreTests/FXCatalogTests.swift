import Testing
@testable import PatternsmithCore

@Suite("FX catalog")
struct FXCatalogTests {
    @Test("Catalog has all 43 entries in index order")
    func catalogCountAndOrder() {
        #expect(FXType.catalog.count == 43)
        #expect(FXType.allCases.count == 43)
        for (i, descriptor) in FXType.catalog.enumerated() {
            #expect(descriptor.index == i)
            // The enum raw value must line up with the catalog index.
            #expect(FXType(rawValue: i)?.descriptor.index == i)
        }
    }

    @Test("Spot-check known effect descriptors")
    func knownDescriptors() {
        #expect(FXType.chance.descriptor.symbol == "C")
        #expect(FXType.chance.descriptor.max == 100)

        #expect(FXType.panning.descriptor.scaled == ScaledRange(min: -50, max: 50))
        #expect(FXType.tempo.descriptor.scaled == ScaledRange(min: 8, max: 400))
        #expect(FXType.microTune.descriptor.scaled == ScaledRange(min: -99, max: 99))

        #expect(FXType.lowPass.descriptor.symbol == "L")
        #expect(FXType.bandPass.descriptor.symbol == "B")
        #expect(FXType.slideDown.descriptor.max == 255)
    }

    @Test("none/off are not effects; others are")
    func isEffect() {
        #expect(FXType.none.isEffect == false)
        #expect(FXType.off.isEffect == false)
        #expect(FXType.roll.isEffect == true)
    }

    @Test("FXCommand clamps and range-checks against its descriptor")
    func clamping() {
        var cc = FXCommand(type: .chance, value: 150)
        #expect(cc.isInRange == false)
        #expect(cc.clampedValue == 100)

        cc.value = 40
        #expect(cc.isInRange == true)
        #expect(cc.clampedValue == 40)

        // Default initializer uses the descriptor default.
        #expect(FXCommand(.tempo).value == 60)
    }
}
