import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

const Hooks = {
  ScrollBottom: {
    mounted() {
      this.el.scrollTop = this.el.scrollHeight;
    },
    updated() {
      this.el.scrollTop = this.el.scrollHeight;
    },
  },
  SubmitShortcut: {
    mounted() {
      this.el.addEventListener("keydown", (event: KeyboardEvent) => {
        if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
          event.preventDefault();
          this.el.requestSubmit();
        }
      });
    },
  },
};

const THEME_KEY = "vibe-theme";

type VibeTheme = "dark" | "light";

function preferredTheme(): VibeTheme {
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function storedTheme(): VibeTheme | null {
  const value = localStorage.getItem(THEME_KEY);
  return value === "dark" || value === "light" ? value : null;
}

function currentTheme(): VibeTheme {
  return storedTheme() ?? preferredTheme();
}

function applyTheme(theme: VibeTheme) {
  document.documentElement.dataset.theme = theme;
}

applyTheme(currentTheme());

document.addEventListener("click", (event) => {
  const target = event.target instanceof Element ? event.target.closest("[data-theme-toggle]") : null;
  if (!target) return;

  const nextTheme = currentTheme() === "dark" ? "light" : "dark";
  localStorage.setItem(THEME_KEY, nextTheme);
  applyTheme(nextTheme);
});

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ?? "";
const liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: Hooks });
liveSocket.connect();

Object.assign(window, { liveSocket });
