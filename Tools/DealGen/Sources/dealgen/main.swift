import Foundation
import HearthsideCore

// Usage: swift run -c release dealgen [--count 10000] [--draw 1|3|both] [--budget 150000]
//                                    [--out ../../Hearthside/Resources/deals] [--first-seed 1]
// Generates solver-verified winnable Klondike deals, split into easy / normal / hard,
// and writes klondike-draw1.json / klondike-draw3.json plus a timing report.

struct Options {
    var count = 10_000
    var draws = [1, 3]
    var budget = 150_000
    var out = "../../Hearthside/Resources/deals"
    var firstSeed: UInt64 = 1
}

func parse() -> Options {
    var options = Options()
    var args = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = args.next() {
        switch arg {
        case "--count": options.count = Int(args.next() ?? "") ?? options.count
        case "--budget": options.budget = Int(args.next() ?? "") ?? options.budget
        case "--out": options.out = args.next() ?? options.out
        case "--first-seed": options.firstSeed = UInt64(args.next() ?? "") ?? options.firstSeed
        case "--draw":
            switch args.next() {
            case "1": options.draws = [1]
            case "3": options.draws = [3]
            default: options.draws = [1, 3]
            }
        case "-h", "--help":
            print("dealgen --count N --draw 1|3|both --budget NODES --out DIR --first-seed SEED")
            exit(0)
        default:
            FileHandle.standardError.write(Data("Unknown argument \(arg)\n".utf8))
            exit(1)
        }
    }
    return options
}

let options = parse()
let outURL = URL(fileURLWithPath: options.out, isDirectory: true)
try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
var reportLines = ["# DealGen report", "", "Generated: \(ISO8601DateFormatter().string(from: Date()))",
                   "Node budget per deal: \(options.budget)", ""]

for draw in options.draws {
    let rules = KlondikeRules.standard(drawCount: draw)
    let generator = DealGenerator(rules: rules, nodeBudget: options.budget)
    let started = Date()
    var lastPrint = Date.distantPast
    let report = generator.generate(count: options.count, firstSeed: options.firstSeed,
                                    maxAttempts: options.count * 30) { found, attempted in
        if Date().timeIntervalSince(lastPrint) > 2 {
            lastPrint = Date()
            print("draw \(draw): \(found)/\(options.count) winnable after \(attempted) deals")
        }
    }
    let wall = Date().timeIntervalSince(started)
    let file = outURL.appendingPathComponent("klondike-draw\(draw).json")
    try report.library.encoded().write(to: file)

    let pct = { (n: Int) in String(format: "%.1f%%", Double(n) / Double(max(report.attempted, 1)) * 100) }
    let lines = [
        "## Draw \(draw)",
        "",
        "| | |",
        "|---|---|",
        "| Deals tried | \(report.attempted) |",
        "| Proven winnable | \(report.winnable) (\(pct(report.winnable))) |",
        "| Budget exhausted (unknown) | \(report.unknown) (\(pct(report.unknown))) |",
        "| No solution in full search | \(report.unwinnable) (\(pct(report.unwinnable))) |",
        "| Easy / normal / hard | \(report.library.easy.count) / \(report.library.normal.count) / \(report.library.hard.count) |",
        "| Average solve time | \(String(format: "%.1f", report.averageMilliseconds)) ms |",
        "| Slowest deal | \(String(format: "%.0f", report.maxMilliseconds)) ms |",
        "| Wall-clock total | \(String(format: "%.1f", wall)) s |",
        ""
    ]
    reportLines += lines
    print(lines.joined(separator: "\n"))
}

try reportLines.joined(separator: "\n").write(to: outURL.appendingPathComponent("REPORT.md"), atomically: true, encoding: .utf8)
print("Wrote deals to \(outURL.path)")
