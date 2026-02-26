# FAQ

Frequently asked questions about Ferri.

---

**Q: Does Ferri need internet?**

A: Only for LLM API calls. All tool execution -- calendar, contacts, health, location, and every other capability -- happens entirely on-device. If the LLM provider is unreachable, you cannot chat, but your data remains accessible locally.

---

**Q: Can I use a local/offline LLM?**

A: Yes. Use the "Custom Endpoint" provider and point it at a local server running on your LAN. Ollama, llama.cpp, vLLM, and any OpenAI-compatible API server will work. This means zero data leaves your device.

---

**Q: Is my data sent to Ferri's servers?**

A: Ferri has no servers. There is no backend, no relay, no analytics endpoint. Your data goes only to the LLM provider you configure, and only the context needed for the current conversation is sent.

---

**Q: Why does Ferri need [X] permission?**

A: Each permission maps to a specific capability with defined tools. Check Settings and then Capabilities for per-capability explanations. Every capability is independently toggleable -- disable any you do not want. Disabling a capability unregisters its tools so the LLM cannot call them.

---

**Q: Can I add my own tools/capabilities?**

A: Yes. Each capability follows the same pattern: a Kotlin platform channel, a Dart channel handler, a registry entry with color and metadata, and tool handlers in the capabilities provider. See [Adding a Capability](Adding-a-Capability) in the wiki for the full walkthrough.

---

**Q: Why Go instead of doing everything in Dart/Kotlin?**

A: Ferri's engine is a Go-based agent framework. Using Go via FFI provides the complete agent loop -- tool dispatch, context management, multi-turn reasoning -- without re-implementing it in Dart. It also gives cross-platform portability: the same Go engine will compile for iOS with minimal changes.

---

**Q: What LLM should I use?**

A: It depends on your priorities:
- **OpenRouter** gives the cheapest access to many models and is recommended for beginners.
- **Claude** and **GPT-4** work best for complex, multi-step tool-calling tasks.
- **Groq** is the fastest for simple queries due to its inference speed.
- **DeepSeek** offers strong performance at lower cost.
- **Custom Endpoint** lets you use any OpenAI-compatible API, including local models.

---

**Q: Can Ferri work offline?**

A: Partially. The chat interface requires an LLM, which normally means internet. However, all tools work offline -- voice I/O uses on-device engines, and every capability executes locally. If you run a local LLM via Custom Endpoint, Ferri works fully offline with no network traffic whatsoever.

---

**Q: Is Ferri available on iOS?**

A: Not yet. Android is the primary platform with 79+ tested tools across 28+ capability domains. iOS support is planned with 82+ total tools, including iOS-exclusive features like Siri integration, HomeKit, Focus Filters, Live Activities, and WidgetKit. See [Android vs iOS](Android-vs-iOS) for the full comparison.

---

**Q: How do channels (Telegram/Discord/Slack) work?**

A: Channels are messaging platform bots managed by Ferri. They let you interact with the agent from outside the app -- send a message to your Telegram bot, and the agent processes it with full access to your enabled capabilities. Channel functionality is currently being tested. On Android, channels run via a foreground service. On iOS (planned), they will require a companion server for push notifications. See [Channels System](Channels-System) for details.

---

**Q: What are "privileged" capabilities?**

A: Capabilities that require manual activation in Android Settings rather than a standard permission dialog. There are three:
- **Notification Listener** -- reads notifications from all apps
- **Accessibility Service** -- interacts with other app UIs
- **Usage Stats** -- accesses app usage history

These are powerful permissions. Android requires the user to navigate to Settings and explicitly enable them, which is intentional friction to ensure informed consent. These capabilities have no iOS equivalent.

---

**Q: How is chat history stored?**

A: Chat history is stored locally on-device. It is never sent to any server. The current conversation's history is sent to the LLM provider as context for multi-turn conversations, but historical conversations are not uploaded anywhere.

---

**Q: What happens if I revoke a permission?**

A: The corresponding capability's tools are unregistered from the agent. The LLM will no longer see those tools in its schema and cannot call them. Re-granting the permission re-registers the tools. No restart is needed.
