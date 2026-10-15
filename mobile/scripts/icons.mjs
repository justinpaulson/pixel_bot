import sharp from "sharp";
import { readFile, writeFile, readdir } from "node:fs/promises";
import path from "node:path";
const root = new URL("../", import.meta.url).pathname;
const source = (
  await readFile(path.join(root, "public/mark.svg"), "utf8")
).replace('rx="16"', 'rx="0"');
const render = (size, output) =>
  sharp(Buffer.from(source))
    .resize(size, size)
    .flatten({ background: "#173f40" })
    .png()
    .toFile(path.join(root, output));
await render(
  1024,
  "ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png",
);
for (const [density, size] of Object.entries({
  mdpi: 48,
  hdpi: 72,
  xhdpi: 96,
  xxhdpi: 144,
  xxxhdpi: 192,
})) {
  for (const filename of ["ic_launcher.png", "ic_launcher_round.png"])
    await render(
      size,
      `android/app/src/main/res/mipmap-${density}/${filename}`,
    );
  // Adaptive icon's safe center occupies 66 of its 108 dp canvas.
  const foreground = `<svg xmlns="http://www.w3.org/2000/svg" width="108" height="108" viewBox="0 0 108 108"><g transform="translate(22 22)">${source.replace(/<svg[^>]*>/, "").replace("</svg>", "")}</g></svg>`;
  await sharp(Buffer.from(foreground))
    .resize(Math.round((size * 108) / 48))
    .png()
    .toFile(
      path.join(
        root,
        `android/app/src/main/res/mipmap-${density}/ic_launcher_foreground.png`,
      ),
    );
}
// A branded launch image replaces the generated framework splash on both platforms.
const splash = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><rect width="1024" height="1024" fill="#f5f6ef"/><g transform="translate(448 448) scale(2)">${(await readFile(path.join(root, "public/mark.svg"), "utf8")).replace(/<svg[^>]*>/, "").replace("</svg>", "")}</g></svg>`;
for (const file of [
  "splash-2732x2732.png",
  "splash-2732x2732-1.png",
  "splash-2732x2732-2.png",
]) {
  await sharp(Buffer.from(splash))
    .resize(2732)
    .png()
    .toFile(
      path.join(root, `ios/App/App/Assets.xcassets/Splash.imageset/${file}`),
    );
}
await writeFile(
  path.join(root, "android/app/src/main/res/values/ic_launcher_background.xml"),
  '<?xml version="1.0" encoding="utf-8"?><resources><color name="ic_launcher_background">#173f40</color></resources>\n',
);
console.log("Pixel icons and launch images generated.");

const resources = path.join(root, "android/app/src/main/res");
for (const directory of await readdir(resources)) {
  if (!directory.startsWith("drawable")) continue;
  const filename = path.join(resources, directory, "splash.png");
  try {
    const { width, height } = await sharp(filename).metadata();
    const size = Math.min(width, height) * 0.18;
    const mark = (await readFile(path.join(root, "public/mark.svg"), "utf8"))
      .replace(/<svg[^>]*>/, "")
      .replace("</svg>", "");
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><rect width="100%" height="100%" fill="#f5f6ef"/><g transform="translate(${(width - size) / 2} ${(height - size) / 2}) scale(${size / 64})">${mark}</g></svg>`;
    await sharp(Buffer.from(svg))
      .png()
      .toFile(filename + ".new");
    await writeFile(filename, await readFile(filename + ".new"));
    const { unlink } = await import("node:fs/promises");
    await unlink(filename + ".new");
  } catch (error) {
    if (
      error.code !== "ENOENT" &&
      !String(error).includes("Input file is missing")
    )
      throw error;
  }
}
