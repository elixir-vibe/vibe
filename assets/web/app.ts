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

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ?? "";
const liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: Hooks });
liveSocket.connect();

Object.assign(window, { liveSocket });
