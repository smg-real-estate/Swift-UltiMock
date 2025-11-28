import Foundation
import SyntaxParser

extension Syntax.TypeName {
    var actualTypeNameExceptSelf: Syntax.TypeName {
        name == "Self" ? self : actualTypeName ?? self
    }

    func escapedIdentifierName() -> String {
        name
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
        if isOptional, let term = unwrappedTypeName.hasPrefix("any ") ? unwrappedTypeName : closure?.asFixedSource {
            "(\((attributes.flatMap(\.value).map(\.asSource).sorted() + [term]).joined(separator: " ")))?"
        } else {
            closure?.asFixedSource ?? name
        }
    }

    func name(convertingImplicitOptional: Bool) -> String {
        let baseName = convertingImplicitOptional && isImplicitlyUnwrappedOptional ? unwrappedTypeName + "?" : fixedName
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

    func actualName(convertingImplicitOptional: Bool) -> String {
        (actualTypeName ?? self).name(convertingImplicitOptional: convertingImplicitOptional)
    }
}
