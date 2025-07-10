package fr.ppprakhar.flutterappbadger;

import android.content.Context;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import me.leolin.shortcutbadger.ShortcutBadger;

/** FlutterAppBadgerPlugin */
public class FlutterAppBadgerPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_app_badger");
        context = binding.getApplicationContext();
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("updateBadgeCount")) {
            int count = call.argument("count");
            if (count >= 0) {
                ShortcutBadger.applyCount(context, count);
            } else {
                ShortcutBadger.removeCount(context);
            }
            result.success(null);
        } else {
            result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
