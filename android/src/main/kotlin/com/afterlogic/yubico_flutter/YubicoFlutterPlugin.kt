package com.afterlogic.yubico_flutter

import android.app.Activity
import android.app.Activity.RESULT_CANCELED
import android.app.Activity.RESULT_OK
import android.content.Intent
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat.startIntentSenderForResult
import com.google.android.gms.common.util.Base64Utils
import com.google.android.gms.fido.Fido
import com.google.android.gms.fido.fido2.api.common.*
import com.google.android.gms.tasks.Tasks
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.util.concurrent.Callable
import java.util.concurrent.LinkedBlockingDeque
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit


/** YubicoFlutterPlugin */
class YubicoFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var callback: ((MutableMap<String, Any>?, PluginError?) -> Unit)? = null
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "yubico_flutter")
        channel.setMethodCallHandler(this)
    }


    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if ((requestCode == REQUEST_CODE_SIGN || requestCode == REQUEST_CODE_REGISTER)) {
            if (data == null || resultCode == RESULT_CANCELED) {
                callback?.invoke(null, PluginError(ErrorCase.Canceled))
                return true
            }
            when (resultCode) {
                RESULT_OK -> {
                    when {
                        data.hasExtra(Fido.FIDO2_KEY_ERROR_EXTRA) -> {
                            val error = data.getByteArrayExtra(Fido.FIDO2_KEY_ERROR_EXTRA)
                                    ?: return false
                            val response = AuthenticatorErrorResponse.deserializeFromBytes(error)
                            mapError(response)
                        }
                        requestCode == REQUEST_CODE_SIGN -> {
                            val bytes = data.getByteArrayExtra(Fido.FIDO2_KEY_RESPONSE_EXTRA)
                            val response = AuthenticatorAssertionResponse.deserializeFromBytes(bytes)
                            mapAuthResponse(response)
                        }
                        requestCode == REQUEST_CODE_REGISTER -> {
                            var bytes = data.getByteArrayExtra(Fido.FIDO2_KEY_RESPONSE_EXTRA)
                            if (bytes == null) {
                                bytes = ByteArray(0)
                            }
                            val response = AuthenticatorAttestationResponse.deserializeFromBytes(bytes)
                            maRegisterResponse(response)
                        }
                    }
                }
                RESULT_CANCELED -> {
                    callback?.invoke(null, PluginError(ErrorCase.Canceled))
                }
                else -> {
                    callback?.invoke(null, PluginError(ErrorCase.InvalidResult, resultCode.toString()))
                }
            }
            return true
        }
        return false
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        try {
            when (call.method) {
                "authRequest" -> {
                    val map = ((call.arguments as? List<*>)?.firstOrNull() as? Map<*, *>)
                            ?: return result.notImplemented()

                    return authRequest(
                            (map["timeout"] as? Number)?.toDouble(),
                            map["challenge"] as String,
                            map["requestId"] as? String,
                            map["rpId"] as String,
                            map["credentials"] as List<String>
                    ) { response, error ->
                        try {
                            if (error != null) {
                                return@authRequest result.error(error.errorCase.ordinal.toString(), error.message, error.error.toString())
                            }
                            if (response == null) {
                                return@authRequest result.error(ErrorCase.EmptyResponse.ordinal.toString(), "", "")
                            }
                            return@authRequest result.success(response)
                        } catch (e: Throwable) {
                            print(e)
                        }
                    }
                }
                "registrationRequest" -> {
                    val map = ((call.arguments as? List<*>)?.firstOrNull() as? Map<*, *>)
                            ?: return result.notImplemented()
                    registrationRequest(
                            (map["timeout"] as? Number)?.toDouble(),
                            map["challenge"] as String,
                            map["requestId"] as? String,
                            map["rpId"] as String,
                            map["rpName"] as String,
                            map["userId"] as String,
                            map["name"] as String,
                            map["displayName"] as String,
                            map["pubKeyCredParams"] as? List<Map<String, Any>>,
                            map["allowCredentials"] as? List<Map<String, Any>>
                    ) { response, error ->
                        if (error != null) {
                            return@registrationRequest result.error(error.errorCase.ordinal.toString(), error.message, error.error.toString())
                        }
                        if (response == null) {
                            try {
                                return@registrationRequest result.error(ErrorCase.EmptyResponse.ordinal.toString(), "", "")
                            } catch (e: Throwable) {
                                print(e)
                            }
                        }
                        return@registrationRequest result.success(response)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Throwable) {
            return result.error(
                    ErrorCase.MapError.ordinal.toString(),
                    e.message ?: "",
                    e.toString()
            )
        }
    }

    private fun registrationRequest(
            timeout: Double?,
            challenge: String,
            requestId: String?,
            rpId: String,
            rpName: String,
            userId: String,
            name: String,
            displayName: String,
            pubKeyCredParams: List<Map<String, Any>>? = null,
            allowCredentials: List<Map<String, Any>>? = null,
            callback: (MutableMap<String, Any>?, PluginError?) -> Unit
    ) {

        try {
            if (this.callback != null) {
                try {
                    this.callback?.invoke(null, null)
                } catch (e: Throwable) {
                    print(e)
                }
                this.callback = null
            }
            val activity = activity ?: return callback(null, null)
            val fido2ApiClient = Fido.getFido2ApiClient(activity.applicationContext)

            val builder = PublicKeyCredentialCreationOptions.Builder()
            builder.setChallenge(Base64Utils.decode(challenge))//+

            val entity = PublicKeyCredentialRpEntity(rpId, rpName, null)
            builder.setRp(entity)//-

            val userEntity = PublicKeyCredentialUserEntity(
                    displayName.toByteArray() /* id */,
                    displayName /* name */,
                    null,
                    displayName)
            builder.setUser(userEntity)//+-


            // Parse parameters
            val parameters: MutableList<PublicKeyCredentialParameters> = java.util.ArrayList()
            if (pubKeyCredParams != null) {
                for (item in pubKeyCredParams) {
                    val type = item["type"] as String
                    val alg = item["alg"] as Int
                    val parameter = PublicKeyCredentialParameters(type, alg)
                    parameters.add(parameter)
                }
            }
            builder.setParameters(parameters)//+-


            builder.setTimeoutSeconds(timeout)//-

            // Parse exclude list
            val descriptors: MutableList<PublicKeyCredentialDescriptor> = java.util.ArrayList()
            if (allowCredentials != null) {
                for (item in allowCredentials) {
                    val id = item["id"] as? String
                    val type = item["type"] as? String
                    if (type == "public-key" && id != null) {
                        val descriptor = PublicKeyCredentialDescriptor(type, Base64Utils.decode(id), null)
                        descriptors.add(descriptor)
                    }
                }
            }
            builder.setExcludeList(descriptors)

            val criteria = AuthenticatorSelectionCriteria.Builder()
//            criteria.setAttachment()
            builder.setAuthenticatorSelection(criteria.build())//+

            val result = fido2ApiClient.getRegisterPendingIntent(builder.build())
            result.addOnSuccessListener {
                this.callback = { map, error ->
                    this.callback = callback
                    callback.invoke(map, error)
                }
                startIntentSenderForResult(
                        activity,
                        it.intentSender,
                        REQUEST_CODE_REGISTER,
                        null,
                        0,
                        0,
                        0,
                        null
                )

            }
        } catch (e: Throwable) {
            callback(null, PluginError(ErrorCase.RequestFailed, e.message ?: "", e))
        }
    }

    private fun authRequest(
            timeout: Double?,
            challenge: String,
            requestId: String?,
            rpId: String,
            credentials: List<String>,
            callback: (MutableMap<String, Any>?, PluginError?) -> Unit
    ) {

        try {
            if (this.callback != null) {
                try {
                    this.callback?.invoke(null, null)
                } catch (e: Throwable) {
                    print(e)
                }
                this.callback = null
            }
            this.callback = null
            val activity = activity ?: return callback(null, null)
            val fido2ApiClient = Fido.getFido2ApiClient(activity.applicationContext)
            val builder = PublicKeyCredentialRequestOptions.Builder()
            builder.setChallenge(Base64Utils.decode(challenge))
            if (timeout != null) {
                builder.setTimeoutSeconds(timeout)
            }
            builder.setRpId(rpId)
            val descriptors = ArrayList<PublicKeyCredentialDescriptor>()
            for (allowedKey in credentials) {
                val publicKeyCredentialDescriptor = PublicKeyCredentialDescriptor(
                        PublicKeyCredentialType.PUBLIC_KEY.toString(),
                        Base64Utils.decode(allowedKey),
                        null)
                descriptors.add(publicKeyCredentialDescriptor)
            }
            builder.setAllowList(descriptors)
            val result = fido2ApiClient.getSignPendingIntent(builder.build())
            result.addOnSuccessListener {
                this.callback = callback
                startIntentSenderForResult(
                        activity,
                        it.intentSender,
                        REQUEST_CODE_SIGN,
                        null,
                        0,
                        0,
                        0,
                        null
                )
            }
        } catch (e: Throwable) {
            callback(null, PluginError(ErrorCase.RequestFailed, e.message ?: "", e))
        }
    }

    private fun mapError(error: AuthenticatorErrorResponse) {
        this.callback?.invoke(
                null,
                PluginError(ErrorCase.ErrorResponse, error.errorMessage ?: "", null)
        )
    }

    private fun maRegisterResponse(response: AuthenticatorAttestationResponse) {
        val clientDataJSON = Base64Utils.encode(response.clientDataJSON)
        val attestationObject: String = Base64Utils.encode(response.attestationObject)

        val map = mutableMapOf<String, Any>(
                "clientDataJSON" to clientDataJSON,
                "attestationObject" to attestationObject
        )
        this.callback?.invoke(map, null)
    }

    private fun mapAuthResponse(response: AuthenticatorAssertionResponse) {
        val clientDataJSON = Base64Utils.encode(response.clientDataJSON)
        val authenticatorData: String = Base64Utils.encode(response.authenticatorData)
        val credentialId: String = Base64Utils.encode(response.keyHandle)
        val signature: String = Base64Utils.encode(response.signature)

        val map = mutableMapOf<String, Any>(
                "authenticatorData" to authenticatorData,
                "clientDataJSON" to clientDataJSON,
                "id" to credentialId,
                "signature" to signature
        )
        this.callback?.invoke(map, null)
    }

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val plugin = YubicoFlutterPlugin()
            val channel = MethodChannel(registrar.messenger(), "yubico_flutter")
            val activity = registrar.activity()
            registrar.addActivityResultListener(plugin)
            plugin.activity = activity
            channel.setMethodCallHandler(plugin)
        }

        const val REQUEST_CODE_SIGN = 129
        const val REQUEST_CODE_REGISTER = 130
    }
}

enum class ErrorCase {
    RequestFailed, EmptyResponse, Canceled, InvalidResult, ErrorResponse, MapError,
}

class PluginError(var errorCase: ErrorCase, var message: String = "", var error: Throwable? = null)