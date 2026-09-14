package com.ensembleui.ensemble_agent

import android.util.Log
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.common.StreamingCallback
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Android plugin for Gemini Nano via ML Kit GenAI Prompt API.
 *
 * Text generate/stream only. Native function calling is not available —
 * Ensemble Dart Path B owns tool orchestration.
 */
class EnsembleAgentPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val cancelledRequestIds = mutableSetOf<String>()
    private val jobs = mutableMapOf<String, Job>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var generativeModel: GenerativeModel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "ensemble_agent")
        eventChannel = EventChannel(binding.binaryMessenger, "ensemble_agent/events")
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        jobs.values.forEach { it.cancel() }
        jobs.clear()
        scope.cancel()
        generativeModel?.close()
        generativeModel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCapabilities" -> {
                scope.launch {
                    try {
                        result.success(capabilitiesMap())
                    } catch (e: Exception) {
                        Log.e(TAG, "getCapabilities failed", e)
                        result.error(
                            "providerError",
                            e.message ?: "Failed to query capabilities.",
                            mapOf("unavailableReason" to "providerError"),
                        )
                    }
                }
            }
            "generate" -> generate(call, result)
            "stream" -> stream(call, result)
            "cancel" -> {
                val requestId = call.argument<String>("requestId")
                if (requestId != null) {
                    cancelledRequestIds.add(requestId)
                    jobs.remove(requestId)?.cancel()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun model(): GenerativeModel {
        val existing = generativeModel
        if (existing != null) return existing
        val created = Generation.getClient()
        generativeModel = created
        return created
    }

    private suspend fun capabilitiesMap(): Map<String, Any?> = withContext(Dispatchers.IO) {
        try {
            when (model().checkStatus()) {
                FeatureStatus.AVAILABLE -> mapOf(
                    "available" to true,
                    "provider" to "gemini_nano",
                    "textGeneration" to true,
                    "streaming" to true,
                    // Path B in Dart — Prompt API has no native function calling.
                    "toolCalling" to true,
                    "nativeToolCalling" to false,
                    "structuredOutput" to false,
                    "imageInput" to true,
                )
                FeatureStatus.DOWNLOADABLE, FeatureStatus.DOWNLOADING -> mapOf(
                    "available" to false,
                    "provider" to "gemini_nano",
                    "textGeneration" to false,
                    "streaming" to false,
                    "toolCalling" to false,
                    "nativeToolCalling" to false,
                    "structuredOutput" to false,
                    "imageInput" to false,
                    "unavailableReason" to "modelDownloading",
                )
                FeatureStatus.UNAVAILABLE -> mapOf(
                    "available" to false,
                    "provider" to "gemini_nano",
                    "textGeneration" to false,
                    "streaming" to false,
                    "toolCalling" to false,
                    "nativeToolCalling" to false,
                    "structuredOutput" to false,
                    "imageInput" to false,
                    "unavailableReason" to "unsupportedDevice",
                )
                else -> mapOf(
                    "available" to false,
                    "provider" to "gemini_nano",
                    "nativeToolCalling" to false,
                    "unavailableReason" to "modelUnavailable",
                )
            }
        } catch (e: GenAiException) {
            Log.e(TAG, "checkStatus GenAiException", e)
            val reason = if (e.errorCode == GenAiException.ErrorCode.AICORE_INCOMPATIBLE) {
                "featureDisabled"
            } else {
                "providerError"
            }
            mapOf(
                "available" to false,
                "provider" to "gemini_nano",
                "nativeToolCalling" to false,
                "unavailableReason" to reason,
            )
        }
    }

    private fun generate(call: MethodCall, result: Result) {
        val requestId = call.argument<String>("requestId") ?: "generate"
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()

        val job = scope.launch {
            try {
                val caps = capabilitiesMap()
                if (caps["available"] != true) {
                    result.error(
                        "unavailable",
                        "Gemini Nano is not available on this device.",
                        caps,
                    )
                    return@launch
                }
                if (cancelledRequestIds.contains(requestId)) {
                    result.error("cancelled", "Request was cancelled.", null)
                    return@launch
                }

                val prompt = buildPrompt(args)
                val text = withContext(Dispatchers.IO) {
                    val request = generateContentRequest(TextPart(prompt)) {
                        // ML Kit Prompt API hard-caps maxOutputTokens to [1, 256].
                        maxOutputTokens = 256
                    }
                    model().generateContent(request).candidates.firstOrNull()?.text.orEmpty()
                }

                if (cancelledRequestIds.contains(requestId)) {
                    result.error("cancelled", "Request was cancelled.", null)
                    return@launch
                }

                result.success(
                    mapOf(
                        "text" to text,
                        "finishReason" to "completed",
                        "toolCalls" to emptyList<Any>(),
                    ),
                )
            } catch (e: Exception) {
                Log.e(TAG, "generate failed", e)
                result.error(
                    "model_error",
                    e.message ?: "Gemini Nano generate failed.",
                    null,
                )
            } finally {
                jobs.remove(requestId)
            }
        }
        jobs[requestId] = job
    }

    private fun stream(call: MethodCall, result: Result) {
        val requestId = call.argument<String>("requestId") ?: "stream"
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()

        // Acknowledge start; tokens flow on the event channel.
        result.success(null)

        val job = scope.launch {
            try {
                val caps = capabilitiesMap()
                if (caps["available"] != true) {
                    eventSink?.success(
                        mapOf(
                            "type" to "failed",
                            "message" to "Gemini Nano is not available on this device.",
                            "code" to "unavailable",
                        ),
                    )
                    return@launch
                }

                val prompt = buildPrompt(args)
                val buffer = StringBuilder()
                withContext(Dispatchers.IO) {
                    val request = generateContentRequest(TextPart(prompt)) {
                        maxOutputTokens = 256
                    }
                    // StreamingCallback delivers newly generated text deltas.
                    model().generateContent(
                        request,
                        StreamingCallback { delta ->
                            if (cancelledRequestIds.contains(requestId)) return@StreamingCallback
                            if (delta.isNullOrEmpty()) return@StreamingCallback
                            buffer.append(delta)
                            scope.launch(Dispatchers.Main) {
                                eventSink?.success(
                                    mapOf(
                                        "type" to "textDelta",
                                        "delta" to delta,
                                    ),
                                )
                            }
                        },
                    )
                }

                if (cancelledRequestIds.contains(requestId)) {
                    eventSink?.success(mapOf("type" to "cancelled"))
                } else {
                    eventSink?.success(
                        mapOf(
                            "type" to "completed",
                            "response" to mapOf(
                                "text" to buffer.toString(),
                                "finishReason" to "completed",
                                "toolCalls" to emptyList<Any>(),
                            ),
                        ),
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "stream failed", e)
                eventSink?.success(
                    mapOf(
                        "type" to "failed",
                        "message" to (e.message ?: "Gemini Nano stream failed."),
                        "code" to "model_error",
                    ),
                )
            } finally {
                jobs.remove(requestId)
            }
        }
        jobs[requestId] = job
    }

    @Suppress("UNCHECKED_CAST")
    private fun buildPrompt(args: Map<*, *>): String {
        val instructions = args["instructions"] as? String
        val messages = args["messages"] as? List<*> ?: emptyList<Any>()
        val body = StringBuilder()
        if (!instructions.isNullOrBlank()) {
            body.append(instructions.trim())
            body.append("\n\n")
        }
        for (raw in messages) {
            val message = raw as? Map<*, *> ?: continue
            val role = message["role"]?.toString() ?: "user"
            val text = message["text"]?.toString()
            val toolResult = message["toolResult"] as? Map<*, *>
            val toolCalls = message["toolCalls"] as? List<*>
            when (role) {
                "user" -> body.append("User: ").append(text.orEmpty()).append('\n')
                "assistant" -> {
                    if (toolCalls != null && toolCalls.isNotEmpty()) {
                        body.append("Assistant tool_calls: ").append(toolCalls).append('\n')
                    }
                    if (!text.isNullOrBlank()) {
                        body.append("Assistant: ").append(text).append('\n')
                    }
                }
                "tool" -> {
                    body.append("Tool(")
                        .append(message["toolCallId"]?.toString().orEmpty())
                        .append("): ")
                        .append(toolResult?.toString().orEmpty())
                        .append('\n')
                }
                "system" -> body.append("System: ").append(text.orEmpty()).append('\n')
            }
        }
        val prompt = body.toString().trim()
        return prompt.ifEmpty { "Hello" }
    }

    companion object {
        private const val TAG = "EnsembleAgent"
    }
}
