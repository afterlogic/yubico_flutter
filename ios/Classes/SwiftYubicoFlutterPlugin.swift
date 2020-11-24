import Flutter
import UIKit
import YubiKit

public class SwiftYubicoFlutterPlugin: NSObject, FlutterPlugin {
    private var nfcSesionStateObservation: NSKeyValueObservation?
    private var accessorySessionStateObservation: NSKeyValueObservation?
    private let channel:FlutterMethodChannel
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "yubico_flutter", binaryMessenger: registrar.messenger())
        let instance = SwiftYubicoFlutterPlugin(channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(_ channel:FlutterMethodChannel) {
        self.channel=channel
        super.init()
        let accessorySession = YubiKitManager.shared.accessorySession as! YKFAccessorySession
        accessorySessionStateObservation =   accessorySession.observe(\.sessionState, changeHandler: { [weak self] session, change in
            DispatchQueue.main.async {
                self?.stateChange()
            }
        })
        if #available(iOS 11.0, *) {
            if(supportNcf()){
                
                let nfcSession = YubiKitManager.shared.nfcSession as! YKFNFCSession
                nfcSesionStateObservation = nfcSession.observe(\.iso7816SessionState, changeHandler: { [weak self] session, change in
                    DispatchQueue.main.async {
                        self?.nfcStateChange()
                    }
                })
            }
        }
        
    }
    
    private func stateChange(){
        let state = YubiKitManager.shared.accessorySession.sessionState
        channel.invokeMethod("stateChange", arguments: state.rawValue)
    }
    

    private func nfcStateChange(){
        if #available(iOS 11.0, *) {
        let state = YubiKitManager.shared.nfcSession.iso7816SessionState
        channel.invokeMethod("nfcStateChange", arguments: state.rawValue)
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        DispatchQueue.global(qos: .utility).async {
            switch call.method {
            case "startSession":
                self.startSession()
                return result("")
            case "startNfcSession":
                if  let map =   (call.arguments as? [Any])?[0] as? [String:Any] {
                self.startNfcSession(map["message"] as! String,
                                     map["success"] as! String)
                }
                return result("")
            case "stopSession":
                self.stopSession()
                return result("")
            case "stopNfcSession":
                self.stopNfcSession()
                return result("")
            case "authRequest":
                if  let map =   (call.arguments as? [Any])?[0] as? [String:Any] {
                    self.authRequest(map["nfc"] as! Bool,
                                     map["domainUrl"] as! String,
                                     map["timeout"] as? Double,
                                     map["challenge"] as! String,
                                     map["requestId"] as? String,
                                     map["rpId"] as! String,
                                     map["credentials"] as!  [String ]
                    ) { (response:[String : Any?]?, error:Error?) in
                        DispatchQueue.main.async {
                            self.sendResult(result, response, error)
                        }
                    }
                }else{
                    result(FlutterMethodNotImplemented)
                }
            case "registrationRequest":
                if  let map =   (call.arguments as? [Any])?[0] as? [String:Any] {
                    
                    self.registrationRequest(map["nfc"] as! Bool,
                                             map["domainUrl"] as! String,
                                             map["timeout"] as? Double,
                                             map["challenge"] as! String,
                                             map["requestId"] as? String,
                                             map["rpId"] as! String,
                                             map["rpName"] as! String,
                                             map["userId"] as! String,
                                             map["name"] as! String,
                                             map["displayName"] as! String,
                                             map["pubKeyCredParams"] as!  [[String : Any]]
                    ) { (response:[String : Any?]?, error:Error?) in
                        DispatchQueue.main.async {
                            self.sendResult(result, response, error)
                        }
                    }
                }else{
                    result(FlutterMethodNotImplemented)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
            
        }
    }
    
    func sendResult(_ result: FlutterResult,_ response:[String : Any?]?,_ error:Error?){
        if(error != nil){
            if(error is PluginError){
                let pluginError = error as! PluginError
                return result(FlutterError.init(code: "\(pluginError.errorCase)", message:  "", details:nil))
            }
            return result(FlutterError.init(code: "\(PluginErrorCase.Undefined)", message:  error?.localizedDescription ?? "", details:nil))
        }else if(response == nil){
            return result(FlutterError.init(code: "\(PluginErrorCase.EmptyResult)", message:  "", details:nil))
        }else{
            return result(response)
        }
    }
    
    func supportNcf() -> Bool{
        guard #available(iOS 13.0, *) else {
            return false
        }
        return  NFCNDEFReaderSession.readingAvailable
        
    }
    func startSession(){
        YubiKitManager.shared.accessorySession.startSession()
    }
    func startNfcSession(_ message  : String,_ success : String){
        if #available(iOS 13.0, *) {
            YubiKitExternalLocalization.nfcScanAlertMessage=message
            YubiKitExternalLocalization.nfcScanSuccessAlertMessage=success
            YubiKitManager.shared.nfcSession.startIso7816Session()
        }
    }
    func stopSession(){
        YubiKitManager.shared.accessorySession.stopSession()
    }
    func stopNfcSession(){
        if #available(iOS 13.0, *) {
            YubiKitManager.shared.nfcSession.stopIso7816Session()
        }
    }
    func registrationRequest(
        _ nfc:Bool,
        _ domainUrl : String,
        _ timeout : Double?,
        _ challenge : String,
        _ requestId : String?,
        _ rpId : String,
        _ rpName : String,
        _ userId : String,
        _ name : String,
        _ displayName : String,
        _ pubKeyCredParams: [[String:Any?]],
        _ handler: @escaping  ([String : Any?]?,Error?)->Void
    )  {
        
        do{
            var fido2Service: YKFKeyFIDO2ServiceProtocol? = nil
            if nfc {
                guard #available(iOS 13.0, *) else {
                    throw PluginError(.NfcNotSupported)
                }
                fido2Service = YubiKitManager.shared.nfcSession.fido2Service
            } else {
                fido2Service = YubiKitManager.shared.accessorySession.fido2Service
            }
            if fido2Service == nil{
                throw PluginError(.NotAttached)
            }
            
            let makeCredentialRequest = YKFKeyFIDO2MakeCredentialRequest()
            
            guard let challengeData = Data(base64Encoded: challenge) else {
                return
            }
            guard let clientData = YKFWebAuthnClientData(type:  .create, challenge:challengeData, origin: domainUrl) else {
                return
            }
            let clientDataJSON = clientData.jsonData!
            let requestId=requestId
            
            makeCredentialRequest.clientDataHash = clientData.clientDataHash!
            let rp = YKFFIDO2PublicKeyCredentialRpEntity()
            rp.rpId = rpId
            rp.rpName = rpName
            makeCredentialRequest.rp = rp
            
            let user = YKFFIDO2PublicKeyCredentialUserEntity()
            user.userId = Data(base64Encoded: userId)!
            user.userName = name
            makeCredentialRequest.user = user
            
            makeCredentialRequest.pubKeyCredParams = []
            pubKeyCredParams.forEach { (map:[String : Any]) in
                
                if( map["type"] as? String == "public-key"){
                    let alg = map["alg"] as? Int
                    if(alg != nil){
                        let param = YKFFIDO2PublicKeyCredentialParam()
                        param.alg = alg!
                        makeCredentialRequest.pubKeyCredParams.append(param)
                    }
                }
                
            }
            
            makeCredentialRequest.options = [AnyHashable:Any]()
            
             fido2Service!.execute(makeCredentialRequest){ (response, error) in
                if error != nil {
                    handler(nil,error)
                }else if response == nil {
                    handler(nil,PluginError(.EmptyResult))
                }else{
                    let clientDataJSON = clientDataJSON.base64EncodedString()
                    let attestationObject = response!.webauthnAttestationObject.base64EncodedString()
                    let attestation = [
                        "clientDataJSON":clientDataJSON,
                        "attestationObject": attestationObject,
                    ] as [String : String?]
                    let id :String? = requestId
                    let map = [
                        "id":id,
                        "attestation": attestation,
                    ] as [String : Any?]
                    handler(map,nil)
                }
            }
        } catch  {
            handler(nil,error)
        }
    }
    
    func authRequest(
        _ nfc:Bool,
        _ domainUrl : String,
        _ timeout : Double?,
        _ challenge:String,
        _ requestId:String?,
        _ rpId:String,
        _ credentialIds:[String],
        _ handler: @escaping  ([String : Any?]?,Error?)->Void
    )  {
        do{
            var fido2Service: YKFKeyFIDO2ServiceProtocol? = nil
            if nfc {
                guard #available(iOS 13.0, *) else {
                    throw PluginError(.NfcNotSupported)
                }
                fido2Service = YubiKitManager.shared.nfcSession.fido2Service
                
            } else {
                fido2Service = YubiKitManager.shared.accessorySession.fido2Service
            }
            if fido2Service == nil{
                throw PluginError(.NotAttached)
            }
            
            let getAssertionRequest = YKFKeyFIDO2GetAssertionRequest()
            
            guard let challengeData = Data(base64Encoded: challenge) else {
                return
            }
            guard let clientData = YKFWebAuthnClientData(type: .get, challenge:challengeData, origin: domainUrl) else {
                return
            }
            let clientDataJSON = clientData.jsonData!
            getAssertionRequest.rpId = rpId
            getAssertionRequest.clientDataHash = clientData.clientDataHash!
            getAssertionRequest.options = [YKFKeyFIDO2GetAssertionRequestOptionUP: true]
            
            var allowList = [YKFFIDO2PublicKeyCredentialDescriptor]()
            for credentialId in credentialIds {
                let credentialDescriptor = YKFFIDO2PublicKeyCredentialDescriptor()
                credentialDescriptor.credentialId = Data(base64Encoded: credentialId)!
                let credType = YKFFIDO2PublicKeyCredentialType()
                credType.name = "public-key"
                credentialDescriptor.credentialType = credType
                allowList.append(credentialDescriptor)
            }
            getAssertionRequest.allowList = allowList
            
            fido2Service!.execute(getAssertionRequest){ (response, error) in
                if error != nil {
                    handler(nil,error)
                }else if response == nil {
                    handler(nil,PluginError(.EmptyResult))
                }else{
                    let clientDataJSON = clientDataJSON.base64EncodedString()
                    let authenticatorData = response!.authData.base64EncodedString()
                    let credentialId = response!.credential!.credentialId.base64EncodedString()
                    let signature = response!.signature.base64EncodedString()
                    let attestation = [
                        "id": credentialId,
                        "authenticatorData": authenticatorData,
                        "clientDataJSON": clientDataJSON,
                        "signature": signature
                    ] as [String : Any?]
                    
                    let id :String? = requestId
                    let map = [
                        "id":id,
                        "attestation":attestation
                    ] as [String : Any?]
                    handler(map,nil)
                }
            }
        } catch  {
            handler(nil,error)
        }
    }
}
class PluginError : Error{
    let errorCase: PluginErrorCase
    init(_ errorCase: PluginErrorCase){
        self.errorCase = errorCase
    }
}
enum PluginErrorCase {
    case Undefined
    case EmptyResult
    case NotAttached
    case NfcNotSupported
}
