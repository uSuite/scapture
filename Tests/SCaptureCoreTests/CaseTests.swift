import Foundation
import Testing
@testable import SCaptureCore

struct CaseStoreTests {
    @Test func ids() {
        for good in ["poc-demo-vm-stop", "guide", "release-2026-10"] {
            #expect(CaseStore.isValidID(good), "\(good)")
        }
        for bad in ["", "Poc-demo", "poc demo", "poc--demo", "-poc", "poc-", "poc_demo", "café"] {
            #expect(!CaseStore.isValidID(bad), "\(bad)")
        }
    }

    @Test func listsCasesNewestFirst() throws {
        let temp = try TempFolder()
        try temp.folder("poc-old", modified: Clock.now.addingTimeInterval(-3600))
        try temp.folder("poc-new", modified: Clock.now)
        try temp.folder("Not A Case")
        try temp.folder(".hidden")
        try temp.touch("loose.png")
        let store = CaseStore(root: temp.url)
        #expect(store.cases().map(\.id) == ["poc-new", "poc-old"])
        #expect(CaseStore(root: temp.url.appendingPathComponent("missing")).cases().isEmpty)
    }

    @Test func createsAndCounts() throws {
        let temp = try TempFolder()
        let store = CaseStore(root: temp.url.appendingPathComponent("root"))
        let url = try store.create("poc-demo-vm-stop")
        #expect(store.exists("poc-demo-vm-stop"))
        #expect(url.lastPathComponent == "poc-demo-vm-stop")
        #expect(throws: CaseStore.CaseError.exists("poc-demo-vm-stop")) {
            try store.create("poc-demo-vm-stop")
        }
        #expect(throws: CaseStore.CaseError.invalidID("Bad")) {
            try store.create("Bad")
        }
        try temp.touch("root/poc-demo-vm-stop/a.png")
        try temp.touch("root/poc-demo-vm-stop/b.jpg")
        try temp.touch("root/poc-demo-vm-stop/memo.md")
        try temp.touch("root/poc-demo-vm-stop/.scap-tmp.png")
        #expect(store.count("poc-demo-vm-stop") == 2)
        #expect(store.names("poc-demo-vm-stop") == ["a.png", "b.jpg", "memo.md"])
        #expect(store.count("missing") == 0)
        #expect(CaseStore.CaseError.noRoot("/x").description.contains("/x"))
    }
}

struct NamerTests {
    let timestamp = Namer(style: .timestamp, timeZone: Clock.utc)
    let step = Namer(style: .caseStep, timeZone: Clock.utc)

    @Test func timestampNames() {
        #expect(timestamp.name(at: Clock.now, caseID: "c", existing: []) == "scap-2026-10-28-093435.png")
    }

    @Test func sameSecondGetsALetter() {
        var existing: Set<String> = []
        var names: [String] = []
        for _ in 0..<3 {
            let name = timestamp.name(at: Clock.now, caseID: "c", existing: existing)!
            names.append(name)
            existing.insert(name)
        }
        #expect(names == ["scap-2026-10-28-093435.png", "scap-2026-10-28-093435b.png", "scap-2026-10-28-093435c.png"])
        #expect(names == names.sorted())
        #expect(names == names.sorted { Sorter.naturalLess($0, $1) })
    }

    @Test func runsOutAfterTwentySixInASecond() {
        var existing: Set<String> = []
        while let name = timestamp.name(at: Clock.now, caseID: "c", existing: existing) {
            existing.insert(name)
        }
        #expect(existing.count == 26)
    }

    @Test func caseStepCountsOn() {
        #expect(step.name(at: Clock.now, caseID: "poc-a-b", existing: []) == "poc-a-b-01.png")
        let existing: Set<String> = ["poc-a-b-01.png", "poc-a-b-07.png", "poc-a-b-x.png", "poc-a-b-c-99.png", "other-12.png", "poc-a-b-١٢.png"]
        #expect(step.name(at: Clock.now, caseID: "poc-a-b", existing: existing) == "poc-a-b-08.png")
        #expect(step.name(at: Clock.now, caseID: "poc-a-b", existing: ["poc-a-b-99.png"]) == "poc-a-b-100.png")
        #expect(Namer.highestStep(caseID: "poc-a-b", in: ["poc-a-b-03.jpg"]) == 3)
    }
}
