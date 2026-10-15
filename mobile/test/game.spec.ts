import { test, expect, Page } from "@playwright/test";

const id = "11111111-2222-3333-4444-555555555555";
const scene = {
  view_box: "0 0 512 512",
  art: {
    tag: "g",
    attributes: {},
    children: [
      {
        tag: "circle",
        attributes: { cx: "256", cy: "256", r: "100", fill: "#b9e6d2" },
        children: [],
      },
    ],
  },
};
function state(phase = "playing") {
  const now = Date.now();
  return {
    id,
    phase,
    share_url: `https://pixel.justinpaulson.com/games/${id}`,
    host: true,
    mode: "solo",
    round_limit: 3,
    drawing_model: "gpt-6-astra",
    server_time: new Date(now).toISOString(),
    round_duration_seconds: 30,
    drawing_duration_ms: 6000,
    players: [{ name: "You", me: true, points: 0, solved: false }],
    round:
      phase === "lobby"
        ? null
        : {
            id: 42,
            number: 1,
            category: "Movies",
            status: phase,
            started_at: new Date(now - 7000).toISOString(),
            ends_at: new Date(now + 23000).toISOString(),
            solved: false,
            next_round_at:
              phase === "revealed" ? new Date(now + 12000).toISOString() : null,
            image_url: "/rounds/42/drawing",
            scene_url: "/rounds/42/drawing.json",
            hint: "A prehistoric adventure",
            answer:
              phase === "revealed" || phase === "complete"
                ? "Jurassic Park"
                : null,
          },
    gallery: [] as any[],
  };
}
async function mock(page: Page, initial = state()) {
  let current = initial;
  let creates: any[] = [];
  let guesses: string[] = [];
  let disconnected = false;
  await page.route("**/api/v1/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    const data = route.request().postDataJSON();
    const reply = (body: unknown, status = 200) =>
      route.fulfill({
        status,
        contentType: "application/json",
        body: JSON.stringify(body),
      });
    if (disconnected) return route.abort();
    if (path === "/api/v1/config") return reply({}, 503);
    if (path === "/api/v1/session")
      return reply({ token: "test-session", name: "You" }, 201);
    if (path === "/api/v1/games" && route.request().method() === "POST") {
      creates.push(data);
      return reply(current);
    }
    if (path.endsWith("/drawing")) return reply(scene);
    if (path.endsWith("/state") || path.endsWith("/join"))
      return reply(current);
    if (path.endsWith("/start")) {
      current = { ...state(), mode: "party" };
      return reply(current);
    }
    if (path.endsWith("/skip")) {
      current = state("revealed");
      current.gallery = [
        { number: 1, answer: "Jurassic Park", image_url: "/rounds/42/drawing" },
      ];
      return reply(current);
    }
    if (path.endsWith("/answer")) {
      guesses.push(data.answer);
      if (data.answer.toLowerCase() === "jurassic park") {
        current = state("complete");
        current.players[0].points = 930;
        current.players[0].solved = true;
        current.gallery = [
          {
            number: 1,
            answer: "Jurassic Park",
            image_url: "/rounds/42/drawing",
          },
        ];
        return reply({ accepted: true, points: 930, message: "Correct! +930" });
      }
      return reply({ accepted: false, message: "Not quite." });
    }
    return reply({ message: "Unexpected endpoint" }, 404);
  });
  return {
    creates,
    guesses,
    set: (value: ReturnType<typeof state>) => {
      current = value;
    },
    offline: (value: boolean) => {
      disconnected = value;
    },
  };
}

test("simple setup preserves options and fits phone widths", async ({
  page,
}) => {
  const api = await mock(page);
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Pixel draws. You guess." }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Friends", exact: true }).click();
  await page.getByLabel("Category", { exact: true }).selectOption("music");
  await page.getByRole("button", { name: "10", exact: true }).click();
  await page.getByRole("button", { name: "Luna Harder" }).click();
  await page.getByRole("button", { name: "Player settings" }).click();
  await page.getByLabel("Nickname").fill("Mina");
  await page.getByRole("button", { name: "Done" }).click();
  await page.getByRole("button", { name: "Create room" }).click();
  await expect.poll(() => api.creates.length).toBe(1);
  expect(api.creates[0]).toEqual({
    mode: "party",
    category: "music",
    round_limit: 10,
    drawing_model: "gpt-6-luna",
    display_name: "Mina",
  });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
});

test("drawing, repeated guesses, focus, results, and gallery work", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  const api = await mock(page);
  await page.goto("/");
  await page.getByRole("button", { name: "Play", exact: true }).click();
  await expect(page.locator("[data-drawing-target=art] circle")).toBeVisible();
  await page.getByLabel("Your guess").fill("Titanic");
  await page.getByRole("button", { name: "Send guess" }).tap();
  await expect(page.getByText("Not quite.")).toBeVisible();
  await expect(page.getByLabel("Your guess")).toBeFocused();
  await page.getByLabel("Your guess").fill("Jaws");
  await page.waitForTimeout(1800);
  await expect(page.getByLabel("Your guess")).toHaveValue("Jaws");
  await page.getByRole("button", { name: "Send guess" }).tap();
  await expect.poll(() => api.guesses.length).toBe(2);
  await page.getByLabel("Your guess").fill("Jurassic Park");
  await page.getByRole("button", { name: "Send guess" }).tap();
  await expect(
    page.getByRole("heading", { name: "Jurassic Park" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Scores, 930 points" }),
  ).toBeVisible();
  await expect(page.locator(".final-score")).toHaveText("930points");
  await page.getByRole("button", { name: "Drawings 1" }).click();
  await expect(page.getByRole("dialog").locator("circle")).toBeVisible();
  expect(errors).toEqual([]);
});

test("invite links are validated and join web rooms", async ({ page }) => {
  await mock(page, { ...state("lobby"), mode: "party", host: false });
  await page.goto("/");
  await page.getByRole("button", { name: "Join room", exact: true }).click();
  await page.getByLabel("Invite link").fill("https://evil.example/games/" + id);
  await page.getByRole("button", { name: "Join", exact: true }).click();
  await expect(
    page.getByRole("dialog").getByText("Paste a Pixel invite link."),
  ).toBeVisible();
  await page
    .getByLabel("Invite link")
    .fill("https://pixel.justinpaulson.com/games/" + id);
  await page.getByRole("button", { name: "Join", exact: true }).click();
  await expect(page.getByText("Waiting for the host")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Start", exact: true }),
  ).toHaveCount(0);
});

test("background clock recovery and offline reconnection preserve a typed guess", async ({
  page,
}) => {
  const api = await mock(page);
  await page.goto("/");
  await page.getByRole("button", { name: "Play", exact: true }).click();
  await page.getByLabel("Your guess").fill("Almost there");
  api.offline(true);
  await expect(page.getByText("Reconnecting…").first()).toBeVisible({
    timeout: 6000,
  });
  await expect(page.getByLabel("Your guess")).toHaveValue("Almost there");
  api.offline(false);
  const updated = state();
  updated.round!.ends_at = new Date(Date.now() + 3000).toISOString();
  api.set(updated);
  await expect(page.locator(".connection")).toHaveCount(0, { timeout: 6000 });
  await expect(page.locator(".clock")).toHaveClass(/urgent/);
  await expect(page.getByLabel("Your guess")).toHaveValue("Almost there");
});

test("host reveal confirms once and exposes the gallery only after reveal", async ({
  page,
}) => {
  await mock(page);
  await page.goto("/");
  await page.getByRole("button", { name: "Play", exact: true }).click();
  await expect(page.getByRole("button", { name: /^Drawings/ })).toHaveCount(0);
  await page.getByRole("button", { name: "Reveal", exact: true }).click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Reveal", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Jurassic Park" }),
  ).toBeVisible();
  await expect(page.getByText(/Next drawing in/)).toBeVisible();
});

test("small screens, tablets, and large text stay usable", async ({
  page,
}, testInfo) => {
  await mock(page);
  await page.goto("/");
  for (const size of [
    { width: 320, height: 568 },
    { width: 768, height: 1024 },
    { width: 844, height: 390 },
  ]) {
    await page.setViewportSize(size);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
    await page
      .getByRole("button", { name: "Play", exact: true })
      .scrollIntoViewIfNeeded();
    await expect(
      page.getByRole("button", { name: "Play", exact: true }),
    ).toBeInViewport();
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await page.evaluate(() => scrollTo(0, 0));
  await page.screenshot({
    path: `artifacts/${testInfo.project.name.toLowerCase()}-home.png`,
    fullPage: true,
  });
  await page.getByRole("button", { name: "Play", exact: true }).click();
  await expect(page.locator("[data-drawing-target=art] circle")).toBeVisible();
  await page.screenshot({
    path: `artifacts/${testInfo.project.name.toLowerCase()}-game.png`,
    fullPage: true,
  });
});
