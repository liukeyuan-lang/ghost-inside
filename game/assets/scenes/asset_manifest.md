# 场景背景素材记录

这两张图是 Godot 游戏内的 **背景层**，基准尺寸均为 1280×720。使用内置 `image_gen` 生成，再按中央裁切缩放。风格参考 `Visuals/04-promo-key-art.png` 与 `Visuals/05-promo-poster-bg.png`，没有直接把宣传图当作可玩地图。

| 文件 | 用途 | 适合叠加的可玩物件位置（屏幕坐标，约） |
| --- | --- | --- |
| `white_corridor_bg.png` | 白色走廊四节点地图 | 登录终端 (100, 300)；四个年代壁龛 (355/535/690/860, 290)；封存侧门 (1030, 290)；档案室出口 (1180, 280) |
| `archive_room_bg.png` | 成长档案室地图 | 三件锚点展示柜 (70/145/220, 310)；六张时间线照片框 (360/430/500/570/640/710, 320)；对话区 (930, 325)；权限壁龛 (1120, 330)；出口 (1240, 310) |

两幅图底部留有宽阔深色行走区域。角色、可点击对象、可更换的照片、文字和按钮都应由游戏单独绘制，不能从背景像素推断碰撞。

## 生成提示词

### 白色走廊

> Production 2D background plate for a 1280×720 Godot game. A psychological memory corridor built from pale hospital-white panels fading into a dark navy void, fixed elevated three-quarter camera, clean polished walkable floor in the lower middle. An empty recessed terminal bay at far left; four distinct empty age-station alcoves along the back wall; one sealed side-door recess and one luminous exit at far right. Art direction from Ghost Inside promotional images: painterly paper collage, chunky pixelated digital-glitch edges, cold cyan-blue with restrained amber reflection and a few red seams. No people, props, documents, readable text, labels, numbers, UI, watermark. Keep bottom 22% mostly dark clear floor. Landscape 16:9.

### 成长档案室

> Production 2D background plate for a 1280×720 Godot game. A Growth Archive Room in the same Ghost Inside 2.5D paper-collage cyber-pixel style. Fixed elevated three-quarter camera, broad clear polished walkable floor. Six empty photo frames in a back-wall timeline; three empty display niches on the left for independent anchor objects; warm recessed conversation arch on the right, but no people; one dark permission alcove and a luminous onward doorway at far right. Navy void, warm memory light, ivory walls, floating paper texture and subtle digital glitch seams. No photos, documents, guitar pick, labels, symbols, readable text, UI, buttons, characters, watermark. Keep bottom 22% mostly dark clear floor. Landscape 16:9.
