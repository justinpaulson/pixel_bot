package com.lillybitgames.pixel;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(PixelVaultPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
