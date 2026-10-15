import { Capacitor, CapacitorHttp, registerPlugin } from "@capacitor/core";
import { Preferences } from "@capacitor/preferences";

const Vault = registerPlugin<{
  get(): Promise<{ value?: string }>;
  set(options: { value: string }): Promise<void>;
  clear(): Promise<void>;
}>("PixelVault");
const native = Capacitor.isNativePlatform();
const origin = native ? "https://pixel.justinpaulson.com" : "";
let credential: string | undefined;
let creating: Promise<void> | undefined;

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

export async function initializeSession() {
  credential = native
    ? (await Vault.get())?.value
    : sessionStorage.getItem("pixel-session") || undefined;
}

export async function clearSession() {
  credential = undefined;
  if (native) await Vault.clear();
  else sessionStorage.removeItem("pixel-session");
  await Preferences.remove({ key: "last-game" });
}

export async function request<T = any>(
  path: string,
  method = "GET",
  data?: object,
): Promise<T> {
  // Only our API can receive the credential, including drawing URLs from state.
  if (
    !/^\/(?:config|session|games(?:\/|$)|rounds\/)/.test(path) ||
    path.includes("..") ||
    path.includes("?")
  )
    throw new Error("Invalid request.");
  const headers: Record<string, string> = {
    Accept: "application/json",
    "Content-Type": "application/json",
  };
  if (credential) headers.Authorization = `Bearer ${credential}`;
  const url = `${origin}/api/v1${path}`;
  let status: number, body: any;
  try {
    if (native) {
      const response = await CapacitorHttp.request({
        url,
        method,
        data,
        headers,
        responseType: "json",
        connectTimeout: 15000,
        readTimeout: 15000,
        disableRedirects: true,
      });
      status = response.status;
      body = response.data;
    } else {
      const response = await fetch(url, {
        method,
        headers,
        body: data ? JSON.stringify(data) : undefined,
        credentials: "omit",
        cache: "no-store",
        redirect: "error",
        signal: AbortSignal.timeout(15000),
      });
      status = response.status;
      body = status === 204 ? null : await response.json();
    }
  } catch {
    throw new ApiError("No connection. Try again.", 0);
  }
  if (status === 401) await clearSession();
  if (status < 200 || status >= 300)
    throw new ApiError(
      body?.message || "Something went wrong. Try again.",
      status,
    );
  return body as T;
}

export async function ensureSession(name: string) {
  if (credential) return;
  if (!creating)
    creating = (async () => {
      const result = await request<{ token: string; name: string }>(
        "/session",
        "POST",
        { display_name: name },
      );
      // Persist before using the session so a storage failure cannot strand a room.
      if (native) await Vault.set({ value: result.token });
      else sessionStorage.setItem("pixel-session", result.token);
      credential = result.token;
    })().finally(() => {
      creating = undefined;
    });
  await creating;
}

export function roomId(value: string): string | null {
  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const input = value.trim();
  if (uuid.test(input)) return input;
  try {
    const url = new URL(input);
    const isWeb =
      url.protocol === "https:" &&
      url.hostname === "pixel.justinpaulson.com" &&
      !url.port;
    const isApp = url.protocol === "pixelguess:" && url.hostname === "games";
    if (!isWeb && !isApp) return null;
    const path = isWeb
      ? url.pathname.match(/^\/games\/([^/]+)\/?$/)?.[1]
      : url.pathname.slice(1);
    return path && uuid.test(path) ? path : null;
  } catch {
    return null;
  }
}
