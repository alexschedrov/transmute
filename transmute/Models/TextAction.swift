//
//  TextAction.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import Foundation

struct TextAction: Identifiable {
    let id = UUID()
    var name: String
    var icon: String  // SF Symbol name
    var prompt: String?
    var localTransform: ((String) -> String)?
    /// When true the UI opens a text input for the user to enter an ad-hoc
    /// prompt instead of applying this action directly.
    var isCustom: Bool = false

    func apply(to text: String) async -> String {
        if let localTransform {
            return localTransform(text)
        }
        if let prompt {
            return await LLMService.shared.process(text: text, prompt: prompt)
        }
        return text
    }

    static let builtIn: [TextAction] = [
        TextAction(name: "Custom Request", icon: "wand.and.stars", isCustom: true),
//        TextAction(name: "Uppercase", icon: "textformat.size.larger",
//                   localTransform: { $0.uppercased() }),
//        TextAction(name: "Lowercase", icon: "textformat.size.smaller",
//                   localTransform: { $0.lowercased() }),
        TextAction(name: "Fix Grammar", icon: "textformat.abc",
                   prompt: "Make minimal corrections only. Fix grammatical errors, spelling, and punctuation. Do not change vocabulary, voice, sentence structure, or style. If the input is already correct, return it unchanged."),
        TextAction(name: "Rewrite", icon: "arrow.trianglehead.2.clockwise",
                   prompt: "Improve clarity and flow while preserving meaning, voice, register, and approximate length. Do not shift tone."),
        TextAction(name: "Professional", icon: "briefcase",
                   prompt: "Rewrite for a business audience: precise, neutral, no slang or idioms. Preserve meaning and length."),
        TextAction(name: "Casual", icon: "face.smiling",
                   prompt: "Rewrite to sound conversational and warm, as if writing to a friend. Avoid formality but stay grammatical."),
        TextAction(name: "Shorter", icon: "arrow.down.right.and.arrow.up.left",
                   prompt: "Reduce length by roughly 30–50% while preserving all key information. Cut redundancy first, then tighten phrasing. Do not change tone."),
        TextAction(name: "Longer", icon: "arrow.up.left.and.arrow.down.right",
                   prompt: "Expand with relevant detail, examples, or nuance that supports the existing point. Preserve tone and voice. Do not pad with filler."),
    ]
}
