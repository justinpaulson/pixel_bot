import { defineConfig, devices } from "@playwright/test";
export default defineConfig({
  testDir: "./test",
  fullyParallel: true,
  use: { baseURL: "http://127.0.0.1:5178", trace: "retain-on-failure" },
  projects: [
    {
      name: "iPhone",
      use: { ...devices["iPhone 13"], defaultBrowserType: "webkit" },
    },
    {
      name: "Android",
      use: { ...devices["Pixel 7"], defaultBrowserType: "chromium" },
    },
  ],
  webServer: {
    command: "npm run dev",
    url: "http://127.0.0.1:5178",
    reuseExistingServer: !process.env.CI,
  },
});
