<p align="center">
  <img src="assets/hero.png" alt="AntigravityZH for Mac" width="100%" />
</p>

<h1 align="center">AntigravityZH for Mac</h1>

<p align="center">
  <strong>「反了你了」—— Google Antigravity 原生 macOS 一键中文助手</strong>
</p>

<p align="center">
  <a href="https://github.com/ruaomol/AntigravityZH-for-Mac/releases/latest">
    <img src="https://img.shields.io/badge/Download-DMG-111319?style=for-the-badge&logo=apple&logoColor=white" alt="Download DMG" />
  </a>
  <img src="https://img.shields.io/badge/macOS-14.0+-2563EB?style=for-the-badge" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/SwiftUI-Native-34A853?style=for-the-badge" alt="SwiftUI Native" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge" alt="MIT License" />
  </a>
</p>

---

> 告别敲命令、找路径、重签名。双击打开，点一下即可把 Google Antigravity 变成中文版。

<p align="center">
  <img src="assets/comic.png" alt="反了你了 六格漫画" width="88%" />
</p>

## 界面预览

<p align="center">
  <img src="assets/preview.png" alt="AntigravityZH for Mac 深浅双色预览" width="100%" />
</p>

## 快速开始

1. 前往 [**Releases**](https://github.com/ruaomol/AntigravityZH-for-Mac/releases/latest) 下载 `AntigravityZH-for-Mac-v1.6.1.dmg`。
2. 打开 DMG，将 **`AntigravityZH.app`** 拖入 `Applications` 文件夹。
3. 双击启动，点击 **`一键汉化`** 即可自动完成独立中文应用创建、汉化注入、本机签名与启动检查。

> 首次打开若 macOS 提示未公证，右键点击 `AntigravityZH.app` 选择「打开」即可；或执行 `xattr -cr /Applications/AntigravityZH.app`。

## 主要特性

- **不改官方原版**：默认生成独立的 `~/Applications/Antigravity 中文.app`，保留官方应用与原始签名；也支持在设置中切换为「直接替换」。
- **自动检测与定位**：自动识别官方版本、运行状态、词典更新，支持 Spotlight 查找与手动更改应用位置。
- **原生 SwiftUI 体验**：60fps 交互式倒置 V 点阵与星尘物理效果，支持瓷白浅色 / 黑曜石深色 / 自动跟随系统无缝切换。
- **安全回退与卸载**：一键还原英文原版、移至废纸篓卸载中文版、或彻底清理备份与缓存。
- **7,298 条中文词典**：覆盖界面、菜单、右键菜单、对话框与加载画面，纯本地运行，不读取账号与网络请求。

## 从源码构建

需要 macOS 14+ 与 Xcode Command Line Tools：

```bash
# 编译 AntigravityZH.app
./macos-app/build-app.sh

# 打包 DMG 安装镜像（输出至 dist/）
./macos-app/build-dmg.sh
```

仍保留命令行脚本供自动化调用：`./install-macos.sh` / `./launch-macos.sh` / `./restore-macos.sh`。

## 致谢与参考

- 本项目的核心中文词典、翻译引擎与补丁方案参考并改编自开源项目：[**yunjuanyunshu114-byte/antigravity-zh-plugin**](https://github.com/yunjuanyunshu114-byte/antigravity-zh-plugin)（保留原 MIT 许可证与版权声明）。
- 本工具仅修改本地客户端资源，非 Google 官方语言包；不采集任何隐私、凭据或遥测数据。
