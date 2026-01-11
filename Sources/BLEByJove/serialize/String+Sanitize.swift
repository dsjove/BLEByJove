//
//  String+Sanitize.swift
//  BLEByJove
//
//  Created by David Giovannini on 1/11/26.
//

import Foundation

public extension String {
	var isValidCVariableName: Bool {
		let regex = "^[a-zA-Z_][a-zA-Z0-9_]*$"
		return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
	}

	var sanitizeCVariableName: String {
		let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isValidCVariableName {
			return trimmed
		}

		var sanitizedName = ""
		if let first = self.first, String(first).range(of: "^[a-zA-Z_]$", options: .regularExpression) != nil {
			sanitizedName.append(first)
		}
		else {
			sanitizedName.append("_") // Default to '_' if invalid first character
		}
		let validSubsequentRegex = "[a-zA-Z0-9_]"
		for char in self.dropFirst() {
			if String(char).range(of: validSubsequentRegex, options: .regularExpression) != nil {
				sanitizedName.append(char)
			}
			else {
				sanitizedName.append("_")
			}
		}
		return sanitizedName
	}
}
