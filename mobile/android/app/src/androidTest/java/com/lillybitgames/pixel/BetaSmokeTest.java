package com.lillybitgames.pixel;

import static org.junit.Assert.*;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.junit.Test;
import org.junit.runner.RunWith;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/** Explicit live-service smoke test; creates one three-round solo game. */
@RunWith(AndroidJUnit4.class)
public class BetaSmokeTest {
    private ActivityScenario<MainActivity> scenario;
    private String js(String code) throws Exception {
        AtomicReference<String> value = new AtomicReference<>();
        CountDownLatch done = new CountDownLatch(1);
        scenario.onActivity(a -> a.getBridge().getWebView().evaluateJavascript(code, result -> { value.set(result); done.countDown(); }));
        assertTrue("WebView callback", done.await(10, TimeUnit.SECONDS));
        return value.get();
    }
    private void until(String expression, int seconds) throws Exception {
        long deadline = System.currentTimeMillis() + seconds * 1000L;
        while (System.currentTimeMillis() < deadline) {
            if ("true".equals(js("Boolean(" + expression + ")"))) return;
            Thread.sleep(300);
        }
        fail("Timed out: " + expression + " Visible UI: " + js("document.body.innerText"));
    }
    private void button(String label) throws Exception {
        js("Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === '" + label + "').click()");
    }
    @Test public void releaseBuildPlaysAndResumesThroughNativeBridge() throws Exception {
        scenario = ActivityScenario.launch(MainActivity.class);
        try {
            until("document.querySelector('.home-screen .primary') || document.querySelector('.modes')", 20);
            button("Solo"); button("3"); button("Play");
            until("document.querySelector('.guess-form')", 100);
            assertFalse(js("document.body.innerText").contains("No connection"));
            until("document.querySelector('.canvas-card svg')", 15);
            js("(() => { const e=document.querySelector('[aria-label=\"Your guess\"]'); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(e,'zzzznotananswer'); e.dispatchEvent(new Event('input',{bubbles:true})); })()");
            until("!document.querySelector('[aria-label=\"Send guess\"]').disabled", 10);
            js("document.querySelector('.guess-form').requestSubmit()");
            until("document.querySelector('.guess-feedback').textContent.trim().length > 1", 10);
            assertFalse(js("document.querySelector('.guess-feedback').textContent").contains("+"));
            // Recreate the native activity to exercise saved credential and room recovery.
            scenario.recreate();
            until("Array.from(document.querySelectorAll('button')).some(b=>b.textContent.trim()==='Resume')", 20);
            button("Resume");
            until("document.querySelector('.room-title')", 20);
            assertFalse(js("document.body.innerText").contains("Please reconnect"));
            for(int round=1; round<=3; round++) {
                until("document.querySelector('.room-title').textContent.trim()==='"+round+" / 3' && document.querySelector('.guess-form')", 100);
                button("Reveal");
                until("document.querySelector('dialog[open] .primary')", 5);
                js("document.querySelector('dialog[open] .primary').click()");
                until("document.querySelector('.reveal h1')", 20);
                assertTrue(js("document.querySelector('.reveal h1').textContent").length()>2);
            }
            until("document.body.innerText.includes('FINAL DRAWING')", 15);
            button("Play again");
            until("document.querySelector('.modes')", 10);
        } finally { scenario.close(); }
    }
}
