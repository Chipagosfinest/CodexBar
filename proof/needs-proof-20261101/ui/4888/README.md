# PR 4888 — packaged app preview and Copy Image

Product `073d0643a51c7dc5e14f3b3f7f27afa27dda3f47`; controller `19fd1f8359cd344011662c16513eac3cf6228d02`.

[Successful actual-app run](https://github.com/Chipagosfinest/CodexBar/actions/runs/41373620841) · [controller/workflow](https://github.com/Chipagosfinest/CodexBar/tree/19fd1f8359cd344011662c16513eac3cf6228d02) · package run `41364828152`.

The freshly built unmodified packaged app ran through its normal startup with locally generated transcripts and synthetic provider replies. Automation opened the shipped Share AI Usage window from the app menu and clicked the actual Copy Image button in light and dark appearances. The real preview reports Image copied. Pasteboard data was cleared before each click and then contained a fresh1200x630 PNG (changeCounts2 and4). All11 acceptance checks passed; the installed app hash matches its package. Source tracked delta is empty.

Both actual-screen captures include a visible native synthetic/full-SHA panel outside the product window. The two clipboard PNGs are the original product output; no banner or pixels were added to those exports. They visually match their light/dark previews, including one spend hero, provider marks, model-family rows and provider rollcall. They contain synthetic amounts, not real usage or account data. No actual account credentials, Keychain prompts, IPs or private endpoints are involved in the displayed flow. Optional unknown fixture endpoints can return404; no successful live-provider validation is inferred. DNS checks are sampled/preflight, not absolute containment.

Original-resolution screen captures and clipboard outputs were inspected. Only those inspected PNGs and supporting logs are published here; no recording claim is made. This proof does not decide the maintainer's information/appearance tradeoffs.

While the package artifact remains available, reproduce the exact controller with:

```sh
gh run rerun 41373620841 -R Chipagosfinest/CodexBar
```
