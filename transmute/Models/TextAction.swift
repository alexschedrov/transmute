//
//  TextAction.swift
//  transmute
//
//  Created by Alex Schedrov on 2/17/26.
//

import Foundation

struct TextAction: Identifiable, Codable {
    let id: UUID
    var name: String
    var prompt: String
    var icon: String  // SF Symbol name

    static let builtIn: [TextAction] = [
        TextAction(id: UUID(), name: "Rewrite", prompt: "Rewrite this text, improving clarity and flow. Return ONLY the rewritten text, nothing else.", icon: "arrow.trianglehead.2.clockwise"),
        TextAction(id: UUID(), name: "Fix Grammar", prompt: "Fix grammar, spelling, and punctuation errors. Return ONLY the corrected text, nothing else.", icon: "textformat.abc"),
        TextAction(id: UUID(), name: "Shorter", prompt: "Make this more concise while preserving meaning. Return ONLY the shortened text, nothing else.", icon: "arrow.down.right.and.arrow.up.left"),
        TextAction(id: UUID(), name: "Longer", prompt: "Expand with more detail and nuance. Return ONLY the expanded text, nothing else.", icon: "arrow.up.left.and.arrow.down.right"),
        TextAction(id: UUID(), name: "Professional", prompt: "Rewrite in a professional business tone. Return ONLY the rewritten text, nothing else.", icon: "briefcase"),
        TextAction(id: UUID(), name: "Casual", prompt: "Rewrite in a casual, friendly tone. Return ONLY the rewritten text, nothing else.", icon: "face.smiling"),
    ]
}
