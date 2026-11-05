import Testing
@testable import ccmodel

/// ProfileFields.validate 校验规则（Task 1 验收标准对应）。
struct ValidationTests {

    /// 全部必填字段就绪的基础值。
    private let validValues: [ProfileField: String] = [
        .baseURL: "https://api.example.com",
        .token: "sk-token",
        .mainModel: "glm-5.3-flash",
    ]

    @Test func validInputReturnsEmptyArray() {
        let errors = ProfileFields.validate(
            displayName: "GLM",
            values: validValues,
            existingNames: ["Kimi"]
        )
        #expect(errors == [])
    }

    @Test func emptyDisplayNameAfterTrimmingIsRejected() {
        for name in ["", "   "] {
            let errors = ProfileFields.validate(
                displayName: name,
                values: validValues,
                existingNames: []
            )
            #expect(errors.contains(.emptyDisplayName))
        }
    }

    @Test func duplicateDisplayNameIgnoresLeadingAndTrailingWhitespace() {
        let errors = ProfileFields.validate(
            displayName: " Kimi ",
            values: validValues,
            existingNames: ["GLM", "  Kimi  "]
        )
        #expect(errors.contains(.duplicateDisplayName))
    }

    @Test func distinctNamePassesDuplicateCheck() {
        let errors = ProfileFields.validate(
            displayName: "Kimi K2",
            values: validValues,
            existingNames: ["Kimi"]
        )
        #expect(errors.isEmpty)
    }

    @Test func emptyRequiredFieldsAreReportedPerField() {
        let values: [ProfileField: String] = [
            .baseURL: "   ",
            .token: "",
            .mainModel: "glm-5.3-flash",
        ]
        let errors = ProfileFields.validate(
            displayName: "GLM",
            values: values,
            existingNames: []
        )
        #expect(errors.count == 2)
        #expect(errors.contains(.emptyRequired(.baseURL)))
        #expect(errors.contains(.emptyRequired(.token)))
    }

    @Test func missingRequiredValuesCountAsEmpty() {
        let errors = ProfileFields.validate(
            displayName: "GLM",
            values: [:],
            existingNames: []
        )
        #expect(errors.count == 3)
        #expect(errors.contains(.emptyRequired(.baseURL)))
        #expect(errors.contains(.emptyRequired(.token)))
        #expect(errors.contains(.emptyRequired(.mainModel)))
    }

    @Test func emptyTierFieldsAreAllowed() {
        var values = validValues
        values[.fable] = ""
        values[.opus] = "  "
        let errors = ProfileFields.validate(
            displayName: "GLM",
            values: values,
            existingNames: []
        )
        #expect(errors == [])
    }

    @Test func missingTierFieldsAreAllowed() {
        let values: [ProfileField: String] = [
            .baseURL: "https://api.example.com",
            .token: "sk-token",
            .mainModel: "glm-5.3-flash",
            .haiku: "haiku-x",
        ]
        let errors = ProfileFields.validate(
            displayName: "GLM",
            values: values,
            existingNames: []
        )
        #expect(errors.isEmpty)
    }

    @Test func multipleErrorKindsAreCollectedTogether() {
        let values: [ProfileField: String] = [.token: ""]
        let errors = ProfileFields.validate(
            displayName: " ",
            values: values,
            existingNames: []
        )
        #expect(errors.count == 4)
        #expect(errors.contains(.emptyDisplayName))
        #expect(errors.contains(.emptyRequired(.baseURL)))
        #expect(errors.contains(.emptyRequired(.token)))
        #expect(errors.contains(.emptyRequired(.mainModel)))
    }
}
