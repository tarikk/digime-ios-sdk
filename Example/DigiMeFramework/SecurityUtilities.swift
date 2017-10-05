//
//  SecurityUtilities.swift
//  Sand
//
//  Created on 07/08/2017.
//  Copyright © 2017 digime. All rights reserved.
//

import Foundation
import Security

enum OSStatusResult: Int32
{
    public typealias RawValue              = Int32
    
    case NoError                           = 0
    case OperationUnimplemented            = -4
    case InvalidParam                      = -50
    case MemoryAllocationFailure           = -108
    case TrustResultsUnavailable           = -25291
    case AuthFailed                        = -25293
    case DuplicateItem                     = -25299
    case ItemNotFound                      = -25300
    case ServerInteractionNotAllowed       = -25308
    case DecodeError                       = -26275
}

public class SecurityUtilities: NSObject {
    
    // MARK: Public functions
    public static func getPrivateKeyHex(p12FileName: String, p12Password: String, privateKeyTag: String) -> String!
    {
        do {
            if let file = Bundle.main.url(forResource: p12FileName, withExtension: "p12")
            {
                let p12Data = try Data(contentsOf: file)
                
                var importResult: CFArray? = nil
                let err = SecPKCS12Import(
                    p12Data as NSData,
                    [kSecImportExportPassphrase as String: p12Password] as NSDictionary,
                    &importResult
                )
                guard err == errSecSuccess
                    else {
                        throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
                }
                
                let identityDictionaries = importResult as! [[String:Any]]
                let identity = identityDictionaries[0][kSecImportItemIdentity as String] as! SecIdentity
                
                var privKey : SecKey?
                
                guard SecIdentityCopyPrivateKey(identity, &privKey) == errSecSuccess
                    else {
                        throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
                }
                
                if #available(iOS 10.0, *)
                {
                    var error:Unmanaged<CFError>?
                    if let cfdata = SecKeyCopyExternalRepresentation(privKey!, &error)
                    {
                        let data:Data = cfdata as Data
                        return data.hexEncodedString()
                    }
                }
                else
                {
                    guard storeKeyInKeychain(tag: privateKeyTag, key: privKey!) == true
                        else {
                            return staticConstants.kSharedPrivateKeyHex
                    }
                    
                    let query = [
                        kSecClass as String: kSecClassKey,
                        kSecAttrApplicationTag as String: privateKeyTag as AnyObject,
                        kSecReturnData as String: kCFBooleanTrue
                        ] as [String:AnyObject]
                    
                    var result: AnyObject?
                    let status = SecItemCopyMatching(query as CFDictionary, &result)
                    
                    if status == noErr, let data = result as? Data {
                        return data.hexEncodedString()
                    }
                }
            }
            else
            {
                print("Oops... no .p12 file is found in the app bundle. Will be using preshared one.")
            }
        }
        catch let error as NSError
        {
            print(error.localizedDescription)
            fatalError()
        }
        
        return staticConstants.kSharedPrivateKeyHex
    }
    
    // MARK: Keychain utility functions
    static func storeKeyInKeychain(tag: String, key: SecKey) -> Bool
    {
        let attribute = [
            String(kSecClass)              : kSecClassKey,
            String(kSecAttrKeyType)        : kSecAttrKeyClassPrivate,
            String(kSecValueRef)           : key,
            String(kSecReturnPersistentRef): true,
            String(kSecAttrApplicationTag) : tag
            ] as [String : Any]
        
        let     status = SecItemAdd(attribute as CFDictionary, nil)
        return  (status == OSStatusResult.NoError.rawValue || status == OSStatusResult.DuplicateItem.rawValue)
    }
}
