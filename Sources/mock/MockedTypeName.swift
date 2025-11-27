import Foundation
import SyntaxParser

struct MockedTypeName {
    let typeName: Syntax.TypeName
    
    init(_ typeName: Syntax.TypeName) {
        self.typeName = typeName
    }
    
    var actualTypeNameExceptSelf: Syntax.TypeName {
        typeName.name == "Self" ? typeName : typeName.actualTypeName ?? typeName
    }

    func name(convertingImplicitOptional: Bool) -> String {
        let baseName = convertingImplicitOptional && typeName.isImplicitlyUnwrappedOptional ? typeName.unwrappedTypeName + "?" : fixedName
        return baseName
            .replacingOccurrences(of: "Swift.Int", with: "Int")
            .replacingOccurrences(of: "Swift.String", with: "String")
            .replacingOccurrences(of: "Swift.Bool", with: "Bool")
            .replacingOccurrences(of: "Swift.Double", with: "Double")
            .replacingOccurrences(of: "Swift.Float", with: "Float")
            .replacingOccurrences(of: "Swift.Array", with: "Array")
            .replacingOccurrences(of: "Swift.Dictionary", with: "Dictionary")
            .replacingOccurrences(of: "Swift.Set", with: "Set")
            .replacingOccurrences(of: "Swift.Optional", with: "Optional")
    }
    
    func nameForSyntaxTypeName(convertingImplicitOptional: Bool) -> String {
        name(convertingImplicitOptional: convertingImplicitOptional)
    }

    func actualName(convertingImplicitOptional: Bool) -> String {
        MockedTypeName(typeName.actualTypeName ?? typeName).name(convertingImplicitOptional: convertingImplicitOptional)
    }

    func escapedIdentifierName() -> String {
        typeName.name
            .replacingOccurrences(of: "->", with: "_ret_")
            .replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "<", with: "_lab_")
            .replacingOccurrences(of: ">", with: "_rab_")
            .replacingOccurrences(of: "[", with: "_lsb_")
            .replacingOccurrences(of: "]", with: "_rsb_")
            .replacingOccurrences(of: "(", with: "_lp_")
            .replacingOccurrences(of: ")", with: "_rp_")
            .replacingOccurrences(of: ":", with: "_col_")
            .replacingOccurrences(of: "?", with: "_opt_")
            .replacingOccurrences(of: "!", with: "_impopt_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "==", with: "_eq_")
    }

    var fixedName: String {
        if typeName.isOptional, let term = typeName.unwrappedTypeName.hasPrefix("any ") ? typeName.unwrappedTypeName : typeName.closure?.asFixedSource {
            "(\((typeName.attributes.flatMap(\.value).map(\.asSource).sorted() + [term]).joined(separator: " ")))?"
        } else {
            typeName.closure?.asFixedSource ?? typeName.name
        }
    }
}
