import Foundation
import ANSITerminal

/// Highlights filters and sorts the options using the provided field.
/// - Parameter field: The field used to fuzzily search the options
/// - Returns: An array of the processed options and their associated indices
private func highlightFilterSort(
    _ options: [String],
    by field: String
) -> [(Int, String)] {
    options.map { option in
        // If the option doesn't match the search, hide it (i.e. make it empty)
        if !option.lowercased().contains(field.lowercased()) {
            return ""
        }
        // Highlight the search in the option
        let highlighted = option.replacingOccurrences(of: field, with: field.bold.blue)
        return highlighted
    }
    // Enumerate to keep track of index order
    .enumerated()
    // Matched options will be listed last
    .sorted(by: { $0.element.isEmpty && !$1.element.isEmpty })
}

private func render(
    prompt: String?,
    options: [String],
    field: String
) -> Int? {
    // Clear below the start of when fzf was called
    restoreCursorPosition()
    clearScreen()
    var (screenHeight, _) = readScreenSize()
    guard !options.isEmpty else { return nil }
    // Add a tick mark for style
    var options = options.map { "- \($0)" }

    var selectedIndex: Int?

    // Process the options if the field isn't empty
    if !field.isEmpty {
        let processed = highlightFilterSort(options, by: field)
        options = processed.map(\.1)
        selectedIndex = options.last!.isEmpty ? nil : processed.last?.0
    }

    // Write a prompt if there is one 
    if let prompt {
        writeln(prompt.bold.blue)
        screenHeight -= 1 // one for prompt
    }
    screenHeight -= 1 // one for field
    // Limit the number of options that can appear on screen
    write(options.dropFirst(byLimit: screenHeight).joined(separator: "\n"))
    moveLineDown()
    write("> \(field)")

    return selectedIndex
}

/// A Swift implementation of the popular TUI, fzf.
///
/// - Parameters:
///     - prompt: An optional prompt for the provided options
///     - options: An array of options to choose from
/// - Returns: The selected option or `nil` if no option was found
func fzf(prompt: String? = nil, options: [String]) -> String? {
    // The state of the search field
    var field = ""
    // The index of the selected option
    var selected: Int?

    selected = render(
        prompt: prompt,
        options: options,
        field: field
    )

    while true {
        clearBuffer()

        guard keyPressed() else { continue }

        let char = readChar()

        switch NonPrintableChar(rawValue: char) {
        // If we selected something, exit
        case .enter where selected != nil:
            restoreCursorPosition()
            clearBelow()
            return options[selected!]
        // If no selection or escaped, exit
        case .escape, .enter:
            restoreCursorPosition()
            clearBelow()
            return nil
        // Handle backspace
        case .del where !field.isEmpty:
            field.removeLast()
            break
        // Handle field entry
        case nil:
            field += String(char)
            break
        default:
            break
        }
        selected = render(
            prompt: prompt,
            options: options,
            field: field
        )
    }
}

private extension Collection {

    func dropFirst(byLimit limit: Int) -> [Element] {
        if count > limit {
            return Array(self.dropFirst(count - limit))
        }
        return Array(self)
    }
}
