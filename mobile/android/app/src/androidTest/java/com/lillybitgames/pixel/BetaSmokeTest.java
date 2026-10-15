package com.lillybitgames.pixel;

import static org.junit.Assert.*;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import android.graphics.Bitmap;
import java.io.File;
import java.io.FileOutputStream;
import org.junit.Test;
import org.junit.runner.RunWith;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/** Live-service smoke test plus a deterministic correct-answer UI regression. */
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

    @Test public void correctAnswerSurvivesInstantRevealOnDevice() throws Exception {
        scenario = ActivityScenario.launch(MainActivity.class);
        try {
            until("document.querySelector('.modes')", 20);
            // Test-only response fixture. Vault, preferences, haptics, and all other
            // native calls stay real; no fixture code ships in the app.
            js("""
                (() => {
                  const original = window.Capacitor.nativePromise;
                  const id = '11111111-2222-3333-4444-555555555555';
                  let solved = false;
                  const game = () => ({
                    id, phase: solved ? 'complete' : 'playing', host: true, mode: 'solo',
                    round_limit: 3, drawing_model: 'gpt-6-astra',
                    server_time: new Date().toISOString(), round_duration_seconds: 30,
                    drawing_duration_ms: 6000,
                    players: [{name:'You',me:true,points:solved ? 1630 : 700,solved}],
                    round: {id:42,number:3,category:'Objects',status:solved ? 'revealed' : 'playing',
                      started_at:new Date(Date.now()-8000).toISOString(),
                      ends_at:new Date(Date.now()+22000).toISOString(),solved,
                      scene_url:'/rounds/42/drawing.json',image_url:'/rounds/42/drawing',
                      answer:solved ? 'Sun' : null,hint:null,next_round_at:null}, gallery:[]
                  });
                  window.Capacitor.nativePromise = function(plugin, method, options) {
                    if (plugin === 'CapacitorHttp' && method === 'request') {
                      const path = new URL(options.url).pathname;
                      let data;
                      if (path.endsWith('/answer')) {
                        solved = true;
                        data = {accepted:true,points:930,message:'Correct! +930'};
                      } else if (path.endsWith('/drawing')) {
                        data = {view_box:'0 0 512 512',art:{tag:'g',attributes:{},children:[
                          {tag:'circle',attributes:{cx:'256',cy:'256',r:'100',fill:'#efad45'},children:[]}
                        ]}};
                      } else if (path.endsWith('/games') || path.endsWith('/state')) data = game();
                      if (data) return Promise.resolve({status:200,data,headers:{},url:options.url});
                    }
                    return original.apply(this, arguments);
                  };
                })()
                """);
            button("Play");
            until("document.querySelector('.guess-form')", 20);
            js("(() => { const e=document.querySelector('[aria-label=\"Your guess\"]'); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(e,'Sun'); e.dispatchEvent(new Event('input',{bubbles:true})); })()");
            js("document.querySelector('.guess-form').requestSubmit()");
            until("document.querySelector('.correct-answer') && document.querySelector('.reveal h1')", 10);
            assertEquals("\"Got it!+930points\"", js("document.querySelector('.correct-answer').textContent"));
            assertEquals("\"Sun\"", js("document.querySelector('.reveal h1').textContent"));
            assertEquals("true", js("document.querySelector('.confetti') !== null"));
            Thread.sleep(350);
            Bitmap screenshot = InstrumentationRegistry.getInstrumentation().getUiAutomation().takeScreenshot();
            File image = new File(InstrumentationRegistry.getInstrumentation().getTargetContext().getExternalFilesDir(null), "correct-answer-build2.png");
            try (FileOutputStream stream = new FileOutputStream(image)) { screenshot.compress(Bitmap.CompressFormat.PNG, 100, stream); }
            screenshot.recycle();
            Thread.sleep(3000);
            assertEquals("\"Got it!+930points\"", js("document.querySelector('.correct-answer').textContent"));
            button("Play again");
            until("document.querySelector('.modes')", 10);
            assertEquals("true", js("document.querySelector('.correct-answer') === null"));
        } finally { scenario.close(); }
    }
}
