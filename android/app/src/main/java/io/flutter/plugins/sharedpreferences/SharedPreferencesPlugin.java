package io.flutter.plugins.sharedpreferences;

import android.content.Context;
import android.content.SharedPreferences;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

/**
 * Real implementation of the shared_preferences MethodChannel.
 *
 * Previously this file was a no-op stub that returned null for every
 * getX and discarded every setX. That broke anything that depended
 * on persisted state across launches — most visibly, the onboarding
 * "Get Started" button (which sets `onboarding_complete=true` but
 * the value was never written, so the next launch asked again).
 *
 * This implementation uses Android's native SharedPreferences with
 * the same `flutter.` key prefix the upstream plugin uses, so any
 * value written by the official plugin would also be readable here
 * and vice versa.
 */
public class SharedPreferencesPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {

    private static final String CHANNEL = "plugins.flutter.io/shared_preferences";
    private static final String PREFS_NAME = "FlutterSharedPreferences";
    private static final String PREFIX = "flutter.";

    private MethodChannel channel;
    private SharedPreferences prefs;
    private SharedPreferences.Editor editor;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context ctx = binding.getApplicationContext();
        prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        editor = prefs.edit();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        prefs = null;
        editor = null;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "getAll": {
                    Map<String, ?> all = prefs.getAll();
                    Map<String, Object> filtered = new HashMap<>();
                    for (Map.Entry<String, ?> e : all.entrySet()) {
                        if (e.getKey() != null && e.getKey().startsWith(PREFIX)) {
                            filtered.put(e.getKey().substring(PREFIX.length()), e.getValue());
                        }
                    }
                    result.success(filtered);
                    break;
                }
                case "setBool":
                    editor.putBoolean(prefixed(keyOf(call)), (Boolean) call.argument("value")).apply();
                    result.success(true);
                    break;
                case "setString":
                    editor.putString(prefixed(keyOf(call)), (String) call.argument("value")).apply();
                    result.success(true);
                    break;
                case "setInt":
                    editor.putInt(prefixed(keyOf(call)), ((Number) call.argument("value")).intValue()).apply();
                    result.success(true);
                    break;
                case "setDouble":
                    // SharedPreferences has no native double — encode as float
                    // (same trick the upstream plugin uses). Explicit (float)
                    // cast required by Java because double→float is narrowing.
                    editor.putFloat(prefixed(keyOf(call)), (float) ((Number) call.argument("value")).doubleValue()).apply();
                    result.success(true);
                    break;
                case "setStringList": {
                    @SuppressWarnings("unchecked")
                    List<String> list = (List<String>) call.argument("value");
                    editor.putStringSet(prefixed(keyOf(call)), new HashSet<>(list)).apply();
                    result.success(true);
                    break;
                }
                case "remove":
                    editor.remove(prefixed(keyOf(call))).apply();
                    result.success(true);
                    break;
                case "clear": {
                    // Only clear keys we own (those with our prefix), so
                    // we don't nuke unrelated prefs in the same store.
                    Map<String, ?> all = prefs.getAll();
                    for (String k : all.keySet()) {
                        if (k != null && k.startsWith(PREFIX)) {
                            editor.remove(k);
                        }
                    }
                    editor.apply();
                    result.success(true);
                    break;
                }
                case "getString":
                    result.success(prefs.getString(prefixed(keyOf(call)), null));
                    break;
                case "getBool":
                    result.success(prefs.getBoolean(prefixed(keyOf(call)), false));
                    break;
                case "getInt":
                    result.success(prefs.getInt(prefixed(keyOf(call)), 0));
                    break;
                case "getDouble":
                    // No native double; decode from the float we stored.
                    // 0.0f (not 0.0) — Java distinguishes float and double
                    // literals and getFloat needs a float default.
                    result.success((double) prefs.getFloat(prefixed(keyOf(call)), 0.0f));
                    break;
                case "getStringList": {
                    java.util.Set<String> set = prefs.getStringSet(prefixed(keyOf(call)), null);
                    if (set == null) {
                        result.success(null);
                    } else {
                        result.success(new ArrayList<>(set));
                    }
                    break;
                }
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            result.error("shared_preferences_error", e.getMessage(), null);
        }
    }

    private static String keyOf(MethodCall call) {
        Object k = call.argument("key");
        return k == null ? null : (String) k;
    }

    private static String prefixed(String key) {
        return key == null ? null : PREFIX + key;
    }
}
