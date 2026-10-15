package com.lillybitgames.pixel;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

@CapacitorPlugin(name = "PixelVault")
public class PixelVaultPlugin extends Plugin {
    private static final String ALIAS = "pixel-player-session";
    private SharedPreferences preferences() {
        return getContext().getSharedPreferences("pixel-vault", Context.MODE_PRIVATE);
    }
    private SecretKey key() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        if (store.containsAlias(ALIAS)) return (SecretKey) store.getKey(ALIAS, null);
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return generator.generateKey();
    }
    @PluginMethod
    public void get(PluginCall call) {
        String encrypted = preferences().getString("credential", null);
        String iv = preferences().getString("iv", null);
        if (encrypted == null || iv == null) { call.resolve(); return; }
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)));
            String value = new String(cipher.doFinal(Base64.decode(encrypted, Base64.NO_WRAP)), StandardCharsets.UTF_8);
            JSObject result = new JSObject();
            result.put("value", value);
            call.resolve(result);
        } catch (Exception error) {
            // A device restore cannot restore the non-exportable key. Start fresh.
            preferences().edit().clear().commit();
            call.resolve();
        }
    }
    @PluginMethod
    public void set(PluginCall call) {
        String value = call.getString("value");
        if (value == null) { call.reject("Missing session."); return; }
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key());
            String encrypted = Base64.encodeToString(cipher.doFinal(value.getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
            String iv = Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP);
            if (!preferences().edit().putString("credential", encrypted).putString("iv", iv).commit()) {
                call.reject("Could not save player session."); return;
            }
            call.resolve();
        } catch (Exception error) { call.reject("Could not save player session."); }
    }
    @PluginMethod
    public void clear(PluginCall call) {
        if (preferences().edit().clear().commit()) call.resolve();
        else call.reject("Could not clear player session.");
    }
}
