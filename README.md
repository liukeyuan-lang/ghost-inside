# Ghost Inside · 案例 001 六关版

使用 Godot 4.7.2 Stable 打开 `game/project.godot`，按 F5 运行。画面为 1280×720 横屏，使用 Compatibility。无需网络。本机已导出 `game/builds/windows/GhostInside_SixScenes.exe`；Git 仓库依照 `.gitignore` 不包含构建文件，从 Git 获取工程后可在 Godot 中选择 Windows Desktop 重新导出。

## 操作

- WASD／方向键：移动；E／Enter：调查或确认；鼠标：点击场景设施和选项。
- 白色走廊按住 Q：意识视野。后四关按 1／2／3：切换事实、情绪、期待层。
- F2：随时从标题重开并清空本次案例进度。

## 已完成

标题授权进入 → 白色走廊四个人生节点 → 成长档案室照片、锚点、对话、因果链和封存判断 → 废弃游戏工作室 → 未来验证中心 → 林远的房间 → 自我手术室 → 林澈主动与父亲谈话，在父亲回应前结束。六关使用上一关写入的意愿档案线索。第一、二关使用独立的 2.5D 游戏地图背景；人物与可交互对象由游戏叠加，地图并非宣传图。

白色走廊必须启动观测器，按住 Q 找到 7 岁的蓝色碎片，再依次恢复 15、18、22 岁节点。18 岁的外部期待写入必须失败并追踪来源；22 岁的伪造结论只能移除，不能替林澈写入新的职业答案。MEMORY DELETED 侧门可见但不可进入。

成长档案室须排列照片，取得比赛报名表、医学院宣传册和吉他拨片，区分父子已说出口的话与推测内容，再建立五张因果卡的顺序。只有承认“影响不等于决定”，才能封存系统伪造结论；父亲和记忆不会被删除。

## 尚未制作

第 3—6 关目前是完整可玩的低成本场景，但尚未配备与前两关同等级的独立背景图。没有制作自由视角 3D、第二案例、存档、账号、设置、多语言、Web 或移动版本。旧版饭桌闪避和认知种子流程已从主游戏移除；旧素材及历史文件仍保留在工程中。当前 Ghost 为有规则的引导角色，不需要在线模型；如日后加入在线评估，必须重新定义其作用和验收标准。

## 验证

`game/tests/six_scene_playthrough.gd` 覆盖完整六关与结局，并连续重开五次；`white_corridor_smoke.gd` 和 `archive_room_smoke.gd` 检查前两关的关键限制。运行记录见 `TEST_REPORT.md`。地图画面截图见 `artifacts/qa_white_corridor.png` 与 `artifacts/qa_archive_room.png`。

白色走廊现在使用脚底/基座 Y 排序的 2.5D 空间：玩家可沿 X/Y 移动，终端和高节点只以基座碰撞，视觉从基座上移，背景和 HUD 固定分层。排序、碰撞、状态机和手动验收步骤见 `docs/levels/01-white-corridor-2_5d.md`。在安装 Godot 4.7.2 后可运行：

```sh
godot --headless --path game --script res://tests/white_corridor_smoke.gd
```
