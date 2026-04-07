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
                   prompt: "Fix grammar, spelling, and punctuation errors. Return ONLY the corrected text, nothing else."),
        TextAction(name: "Rewrite", icon: "arrow.trianglehead.2.clockwise",
                   prompt: "Rewrite this text, improving clarity and flow. Return ONLY the rewritten text, nothing else."),
        TextAction(name: "Professional", icon: "briefcase",
                   prompt: "Rewrite in a professional business tone. Return ONLY the rewritten text, nothing else."),
        TextAction(name: "Casual", icon: "face.smiling",
                   prompt: "Rewrite in a casual, friendly tone. Return ONLY the rewritten text, nothing else."),
        TextAction(name: "Shorter", icon: "arrow.down.right.and.arrow.up.left",
                   prompt: "Make this more concise while preserving meaning. Return ONLY the shortened text, nothing else."),
        TextAction(name: "Longer", icon: "arrow.up.left.and.arrow.down.right",
                   prompt: "Expand with more detail and nuance. Return ONLY the expanded text, nothing else."),
    ]
}
