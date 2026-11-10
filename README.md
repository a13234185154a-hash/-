# Days —— 天数记录 App（iOS 本地自用）

正计时（在一起第 X 天）+ 倒计时（距 XX 还有 X 天）+ 可自定义图片背景 + 桌面小组件。
无需 Mac：代码在 Windows 编写，用 GitHub Actions 的 macOS 云主机编译，Sideloadly 签名安装。

## 你需要做的（一次性）

1. **注册 GitHub 账号**（github.com，免费）
2. **新建仓库**：右上角 + → New repository → 名字随意（如 `days-ios`）→ Public（免费无限编译）→ Create
3. **上传本工程全部文件**到仓库（两种方式任选）：
   - 网页端：仓库页 Add file → Upload files，把 `days-ios` 文件夹里的所有内容拖进去 → Commit
   - 命令行（Windows 安装 git 后）：
     ```
     cd days-ios
     git init && git add -A && git commit -m "init"
     git branch -M main
     git remote add origin https://github.com/你的用户名/days-ios.git
     git push -u origin main
     ```
4. **等待云编译**：仓库页 → Actions 标签 → 看到 "Build IPA" 在跑（约 5-10 分钟）→ 变绿后点进去 → Artifacts 区域下载 `Days-unsigned-ipa` → 解压得到 `Days-unsigned.ipa`

## 安装到 iPhone（Windows 电脑）

5. 下载 **Sideloadly**（sideloadly.io），手机用数据线连电脑
6. 打开 Sideloadly：拖入 `Days-unsigned.ipa` → 填你的 Apple ID → Start → 输密码 → 等完成
7. 手机上：设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID 开发者证书；iOS 16+ 还要开 设置 → 隐私与安全性 → 开发者模式
8. 打开 App 添加事件，长按桌面 → 添加小组件 → 搜 "Days"

## 续签（7 天一次）

- 手机装 **SideStore**（sidestore.io），用它装 Days 的 ipa，之后手机上自续签，不用连电脑
- 或嫌麻烦：688 元/年开发者账号，一次签一年

## 日常改功能

改完代码 → `git push`（或网页重新上传改动文件）→ Actions 自动重新编译 → 下载新 ipa → Sideloadly 重装（数据在 App Group 里，重装不丢）。

## 工程结构

```
days-ios/
├── project.yml                  # XcodeGen 工程描述（CI 上自动生成 .xcodeproj）
├── App/
│   ├── DaysApp.swift            # 入口
│   ├── Models.swift             # 数据模型 + 天数计算 + App Group 存储（双目标共用）
│   ├── Views.swift              # 首页列表 + 卡片 + 添加/编辑（含图片背景）
│   └── Days.entitlements
├── Widget/
│   ├── DaysWidget.swift         # 桌面/锁屏小组件（长按可切换事件）
│   └── DaysWidget.entitlements
└── .github/workflows/build.yml  # GitHub Actions 云编译为未签名 ipa
```

## 技术要点

- 数据以 JSON 存在 App Group（`group.com.daysapp.shared`）的 UserDefaults，小组件直接读取
- 图片压缩后存 App Group 容器目录，App 与小组件共用
- 事件变化时调用 `WidgetCenter.reloadAllTimelines()` 刷新小组件；时间线每天零点后自动重算天数
- 小组件用 AppIntentConfiguration 实现"长按 → 编辑 → 选择事件"（iOS 17+）
- CI 产出**未签名** ipa，签名由 Sideloadly 用你的 Apple ID 完成

## 常见问题

- **Actions 报错找不到 scheme**：确认推送的是仓库根目录下的 project.yml（不是多套了一层文件夹）
- **装不上 / 报签名错误**：免费 Apple ID 7 天 3 App 限制；检查设备管理里是否信任了证书
- **小组件不显示数据**：先打开一次 App；若仍不行，免费账号签名时 App Group 权限可能被剥离，删除小组件重新添加，或检查 Sideloadly 是否有 "Remove entitlements" 之类选项需取消勾选
