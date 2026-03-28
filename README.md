# ScreenBlocker

一个给竖屏副显示器用的 macOS 菜单栏工具。它会在竖屏上方放置遮挡区，并尽量把其他应用窗口约束到下半部分，减少抬头看高处内容的负担。

## 当前能力

- 在竖屏显示器上方显示遮挡层
- 自动把普通窗口压回可用区域
- 尽量处理窗口全屏或铺满后的回退位置
- 保留顶部菜单栏区域，不再让遮挡层吞掉系统菜单栏
- 提供菜单栏入口和设置面板

## 运行要求

- macOS 14 或更高版本
- 至少一块竖屏显示器
- 需要给应用开启“辅助功能”权限，否则无法移动其他应用窗口

## 本地运行

直接用 Xcode：

```bash
open ScreenBlocker.xcodeproj
```

或者命令行构建：

```bash
xcodebuild \
  -project ScreenBlocker.xcodeproj \
  -scheme ScreenBlocker \
  -configuration Debug \
  build \
  CODE_SIGNING_ALLOWED=NO
```

## 生成 DMG

仓库现在自带打包脚本：

```bash
./scripts/create-dmg.sh
```

生成结果会放在：

```bash
dist
```

默认产物是未签名 `.dmg`。本地首次打开时，macOS 可能会提示来源未验证，需要手动确认打开。

## GitHub Actions

仓库包含一个 `Build DMG` 工作流：

- 推送到 `main` 时会自动构建并上传 `.dmg` artifact
- 手动触发工作流时也会生成 `.dmg`
- 推送 `v*` 标签时，会把 `.dmg` 挂到 GitHub Release

如果你想让别人直接下载安装包，最合适的做法是发一个版本标签，例如：

```bash
git tag v1.0.0
git push origin v1.0.0
```

这样 GitHub Releases 里就会出现对应的 `.dmg` 文件。

## 已知限制

- 一些应用的特殊窗口、全屏模式或自绘窗口不一定完全受控
- 当前打包产物没有开发者签名和 notarization
- 多显示器布局非常特殊时，仍然可能需要继续微调窗口吸附逻辑
