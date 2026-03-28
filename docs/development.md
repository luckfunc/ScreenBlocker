# 开发说明

这个文档面向维护者，不面向普通使用者。

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

仓库自带打包脚本：

```bash
./scripts/create-dmg.sh
```

生成结果在：

```bash
dist
```

## GitHub Actions

仓库包含 `Build DMG` 工作流：

- 推送到 `main` 时自动构建并上传 `.dmg` artifact
- 手动触发 workflow 时也会生成 `.dmg`
- 推送 `v*` 标签时，会把 `.dmg` 挂到 GitHub Release

## 发布一个版本

最简单的发布方式：

```bash
git tag v0.1.0
git push origin v0.1.0
```

推送后，GitHub Actions 会构建 `.dmg` 并附加到对应 Release。
