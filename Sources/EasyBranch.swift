// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import RegexBuilder
import Foundation
import ANSITerminal

@main
struct EasyBranch: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "A tool to easily find and checkout git branches using fuzzy search",
        version: "1.1.0"
    )

    @Argument(
        help: "A string used to fuzzily find the branch you want to checkout"
    )
    var search: String = ""

    @Option(name: .shortAndLong, help: "The path to a git repository", completion: .directory)
    var repository = "."

    @Flag(name: .shortAndLong, help: "If `git checkout` should be performed on the found branch")
    var checkout: Bool = false

    var retryCount = 0

    mutating func run() throws {

        // Get branches matching the search argument
        let branches = try getBranches()

        switch branches.count {
        // Retry again, fetching the latest from remote if not found locally
        case 0 where retryCount < 1:
            retryCount += 1
            try shell("git fetch", at: repository)
            try run()
            return
        // Retry count exhausted
        case 0:
            Self.exit(withError: Error.branchNotFound(search: search))
        // Only one matching branch found, check it out
        case 1:
            if checkout {
                let output = try shell("git checkout \(branches.first!)")
                print(output)
            } else {
                print(branches.first!)
            }
        // Multiple matches found, narrow the search further
        default:
            storeCursorPosition()
            guard let selection = fzf(
                prompt: "Choose a branch:",
                options: branches
            ) else {
                Self.exit(withError: nil)
            }
            if checkout {
                let output = try shell("git checkout \(selection)", at: repository)
                print(output)
            } else {
                print(selection)
            }
        }
        Self.exit(withError: nil)
    }

    /// Gets local and remote branches matching the `search` argument
    /// - Returns: An array of branch names
    func getBranches() throws -> [String] {
        let currentBranch = try shell("git branch --show-current", at: repository)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let branches = try shell(
            "git -P branch -a --format '%(refname:short)' --sort=committerdate",
            at: repository
        )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "origin/", with: "")
            .split(separator: "\n")
            .unique
            .map(String.init)
            .filter { $0 != "HEAD" && $0 != currentBranch }

        if !search.isEmpty {
            return branches.filter {
                $0.lowercased().contains(search)
            }
        }

        return branches
    }
}

extension EasyBranch {

    enum Error: Swift.Error {
        case branchNotFound(search: String)

        var description: String {
            switch self {
            case .branchNotFound(search: let search):
                "No branch found matching '\(search)'"
            }
        }
    }
}

extension Sequence where Element: Hashable {

    var unique: [Element] {
        var unique = Set<Element>()
        return filter { unique.insert($0).inserted }
    }
}
