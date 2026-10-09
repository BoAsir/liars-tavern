---
name: release-update
description: Use when the user asks to 打包、发布、发版、出新版本、推送在线更新、让玩家更新到最新、上传安装包到 GitHub Releases, or to ship / release / publish a new build of 骗子酒馆 (Liar's Tavern); also when build.json, tools/release.sh, tools/publish_update.sh, tools/publish_release.sh, the updates branch or the signing key come up in a release context.
---

# 发布更新(骗子酒馆)

## 原则

**只发布已提交并推送到 origin/main 的提交，所有测试、导出、签名、推送都在该提交的干净 worktree 里做。** 主工作区常有别的会话没提交的改动，绝不能进包。机械步骤全在 `scripts/ship.sh` 里(它会调用 `tools/release.sh`、`publish_update.sh`、`publish_release.sh`)，不要自己手动拼这些命令。

**main 上 `build.json` 的 `version` 一变(远端还没有 tag `v<version>`),GitHub Actions(`.github/workflows/release.yml`)就自动发布**：测试、导出签名、推 `updates` 分支、建 Release，全部复用 `scripts/ship.sh`。所以平时发布 = 改好 `build.json` 推到 main;本机 `$SHIP` 只在 CI 用不了时兜底，两边绝不同时发同一版。

用户说「发布」就等于授权推更新源和建 GitHub Release，不用再确认，也不要问版本号这类问题，自己定、事后汇报。用户没让发布时，绝不自己发：更新推出去后，所有玩家下次启动就会装上，**撤不回**。

## 流程

`SHIP=.claude/skills/release-update/scripts/ship.sh`(不带参数运行会打印用法)

1. **看要发什么**：`git fetch -q --tags origin && git log --oneline $(git describe --tags --abbrev=0)..HEAD`。没有新内容就不发；只缺 GitHub Release 时用 `$SHIP github`。
2. **只提交自己的改动**：先 `git diff --cached --name-only`，暂存区必须是空的(有别人的文件就别动它们，用 `git commit -- <你的文件>`)。然后 `git add <具体文件>`，不用 `git add -A`、`git add .`。
3. **改 `build.json`**，和改动一起提交在当前分支上：
   - `build` 加一，每次发布都要加，哪怕只是重发。
   - `version`：修 bug 改第三位，新玩法或新功能改第二位。
   - `base_build`：改了 `project.godot`(自动加载、渲染设置等)、升级了 Godot，或者新内容依赖 `src/update/update_boot.gd` / `update_key.gd` 的改动(这两个文件只随安装包生效)时，设成新的 `build`；否则不动。设了就意味着**所有老玩家都得重装**，要在汇报和 Release 说明里写清楚。
   - `notes`:给玩家看的更新说明，显示在主菜单提示条的一行里：一句话，不超过 60 字，以「修复:」或「新增:」开头。CI 用它；和线上上一版一样时 CI 会拦下。
   - GitHub Release 正文可选写在 `docs/releases/v<version>.md`,不写按模板生成。`base_build = build` 时一定要写，第一段就说明老玩家需要重新下载安装包(没有这个文件 CI 不发)。
   - 提交信息照惯例把版本写在末尾：`fix: ……;版本 0.5.3`。
4. **推送前先测**：`$SHIP test`，在这个提交的干净 worktree 里跑全量单测。没过就不推送，先修(superpowers:systematic-debugging)。
5. **推送 = 发布**：`git push origin HEAD && git push origin HEAD:main`。main 快进不了就停下告诉用户，不要强推。推上去后 CI 自动发布：`gh run list --workflow release.yml -L 3` 找到这次运行，`gh run watch <id> --exit-status` 放到后台等结果(约 15–25 分钟，首次要下载 Godot 导出模板更久)。失败时 `gh run view <id> --log-failed` 看原因，修好后 `gh run rerun <id> --failed`(publish 会认出已推过的更新源，只补 Release);要换提交重发就 build 再加一重推。
6. **本机兜底(只在 CI 用不了时)**:`$SHIP all "修复:……" [发布说明.md]`,放到后台执行。先确认 CI 没在发这一版(`gh run list --workflow release.yml`)。
   - 第一个参数是给玩家看的更新说明，显示在主菜单提示条的一行里：一句话，不超过 60 字，以「修复:」或「新增:」开头。
   - 发布说明.md 是 GitHub Release 页面的正文，可以不给，不给时按模板生成。`base_build = build` 时一定要自己写一份，第一段就说明老玩家需要重新下载安装包。
   - `all` 依次做这几步：检查，测试，导出并签名，推 `updates` 分支并等线上读到新 build，建 GitHub Release `v<version>`(发布后会下载回来核对)。任何一步失败，后面的都不做。要分步执行时，用 `check`、`build`、`publish`、`github` 这几个子命令。
7. **汇报并更新记忆**：汇报版本、build、更新说明、Release 链接，以及是否需要重装；然后更新记忆 `liars-tavern-release-flow` 里「已经发布到哪个 build」那一条。

## 出了问题

| 情况 | 处理 |
|---|---|
| `check` 报 build 没加、version 没改、base_build 不对、没推送、tag 已存在 | 按提示改 `build.json` 或推送，提交后重跑 |
| 测试没过，或者「只跑了 N/M 个测试脚本」 | 不发布。后一种是某个测试脚本解析失败被 GUT 悄悄跳过了，照样要修 |
| 缺签名私钥 `~/.config/liarstavern/update_signing_key.pem` | **停下，找用户要备份。绝不运行 `tools/make_update_key.gd` 重新生成**：新私钥签的包，所有已安装的游戏都不认 |
| `publish` 等不到线上的新 build | raw.githubusercontent.com 的缓存最多 5 分钟；重跑 `$SHIP publish`(可以重复执行) |
| `github` 失败(gh 没登录、网络问题、提交里没有 `tools/publish_release.sh`) | 更新源已经生效了。修好后单独重跑 `$SHIP github`；gh 没登录就让用户运行 `gh auth login` |
| CI 报 `LIARS_UPDATE_SIGNING_KEY` 没配或和公钥不是一对 | 让用户在仓库 Settings → Secrets and variables → Actions 配好(内容是本机 `.pem` 全文:`gh secret set LIARS_UPDATE_SIGNING_KEY < ~/.config/liarstavern/update_signing_key.pem`),然后 rerun |
| CI 的 plan 报缺更新说明、说明和上一版一样 | 改 `build.json` 的 `notes` 提交推送(会再次触发);或在 Actions 页面手动运行 Release 并填 notes |
| 发出去的版本有严重问题 | **没法回退**：游戏只接受更大的 build。立刻修好，build 再加一重新发。在那之前，玩家可以加启动参数 `-- --no-update` 退回安装包自带的版本；更新后的版本连续两次启动失败，游戏也会自动退回 |

## 红线

- 在共用的主工作区里直接跑 `tools/release.sh`(会把别人没提交的改动打进包；`OUT` 不对时还会绕过 build 号检查)
- 发布没提交或没推送的代码、同一个 build 号发两次
- 手动改或强推 `updates` 分支、把 `.pem` 放进仓库
- 不打算发布时在 main 上改 `build.json` 的 `version`(一推上去 CI 就发了)
- CI 在发某一版时，本机再跑 `$SHIP publish` / `github` 发同一版
- 用 `SHIP_OUT` 试跑出来的产物对外发布(脚本也会拦)
