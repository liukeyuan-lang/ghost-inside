# Ghost Inside · 案例 001 六关版验证

验证日期：2026-09-24。Godot 4.7.2 Stable，Compatibility，Windows 1280×720。

| 项目 | 结果 |
| --- | --- |
| Godot 工程载入及图片导入 | 通过，无脚本编译错误或丢失资源 |
| 标题进入六关及开放结局 | 通过 |
| 白色走廊观测器、Q 视野、四年龄节点、侧门锁定、出口条件 | 通过 |
| 成长档案室照片、三锚点、父子对话、五张因果卡、判断及封存 | 通过 |
| 第 3—6 关的调查条件与前关线索衔接 | 通过 |
| F2 重开后清除关卡进度与意愿档案 | 通过 |
| 源工程连续五次完整自动试玩 | 通过，SIX_SCENE_FIVE_RUNS_PASS |
| Windows 独立版连续五次完整自动试玩 | 通过，SIX_SCENE_FIVE_RUNS_PASS |
| Windows 版从工程外目录启动 | 通过，退出码 0 |
| 前两关实际地图截图检查 | 通过，见 artifacts/qa_white_corridor.png、qa_archive_room.png、qa_white_corridor_vision.png、qa_archive_room_puzzle.png |

源工程测试入口：`game/tests/six_scene_playthrough.gd`、`white_corridor_smoke.gd`、`archive_room_smoke.gd`。Windows 独立版在 `artifacts` 目录中以 `--headless -- --self-test` 运行，输出记录见 `artifacts/export_self_test.out` 与 `.err`。五次自动试玩逐关完成，覆盖错误照片顺序、未按 Q 寻找碎片、错误判断不授予封存权限、重开清空本次进度，并检查导出版本实际加载两张地图。测试属于程序模拟玩家操作，地图外观另由实际游戏画面截图核对。

本机导出文件：`game/builds/windows/GhostInside_SixScenes.exe`。不依赖项目文件或网络；构建文件按 `.gitignore` 不上传 Git。关卡 3—6 尚未配置独立的高精度 2.5D 背景；目前用现有角色素材和绘制场景。旧饭桌与认知种子内容不在当前主流程。在线模型未用于当前关卡判断。

自检结束时 Godot 输出对象清理提示；发生在测试主动退出之后，五次流程和退出码均正常。尚未在其他电脑型号上验证硬件兼容性。
