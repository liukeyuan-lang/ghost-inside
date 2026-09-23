# Ghost Inside · Tripo 3D 素材提示词

用途：生成核心道具或固定镜头房间，再渲染为 2.5D 分层图片。Godot 运行时保持单屏 2D，不依赖实时 3D。

## 统一风格尾句

将下面内容追加到每条提示词末尾：

> Game-ready low-to-mid-poly 3D asset for a fixed-camera 2.5D narrative puzzle game, near-future psychological treatment space, semi-realistic anime visual style, clean readable silhouette, cold white, blue-black and cyan materials, restrained amber accent, subtle digital fragmentation, clean topology, PBR materials, realistic scale, no characters, no readable text, no logo, no watermark.

## 优先生成的七件核心道具

### 场景 01 · 结局双出口

> A freestanding dual-exit portal structure. Left opening emits sterile hospital-white light. Right opening contains a faint warm miniature-planet glow. Between them is an unfinished translucent region made of sparse floating glass fragments. Both exits remain equally plausible, no good-or-evil symbolism.

### 场景 02 · 记忆投影仪

> A compact tabletop memory projector combining an old family slide projector with restrained near-future holographic optics. Rectangular body, one large lens, paper-photo intake slot, subtle cyan diagnostic light and one worn amber detail. Separate lens and photo tray parts.

### 场景 03 · 三模块插槽架

> A desktop modular data rack with exactly three large removable square slots arranged horizontally. The slots represent WORLD, CHARACTER and ENDING but contain no readable text. Each slot has a different abstract icon shape. Worn indie game studio equipment, cyan circuitry, amber handmade repair marks.

### 场景 04 · 人生模拟器

> A symmetrical tabletop life-path simulator with two opposing input bays, one pristine and orderly, one repaired and asymmetrical. Central transparent calculation core, card-sized evidence slots, cyan scan light, small amber uncertainty pulse. No labels or numbers.

### 场景 04 · 可翻转结果印章

> A heavy reversible verdict stamp for a psychological simulation system. One side looks precise and institutional, the hidden reverse side has an open unresolved symbol. Dark metal, white ceramic grip, thin cyan edge light, subtle worn amber seam.

### 场景 05 · 记忆镜

> A freestanding rectangular memory mirror for a teenager's bedroom. Dark glass does not reflect the room; it projects a faint sequence of footsteps and life milestones. Thin blue-black frame, cyan scan edges, one incomplete amber path at the far end. Separate mirror plane and frame.

### 场景 06 · 手术台控制台与诊断环

> A non-medical consciousness surgery bed integrated with a diagnostic console. Human-sized reclined platform, five independent cable ports around a transparent central core, a large rotatable diagnostic ring with two stable detents, cold white shell, dark glass panels, cyan structure lines, restrained red error light. Avoid gore and conventional hospital machinery.

## 六间房概念图

统一要求：

> Fixed wide camera, 1200x438 stage composition, slight elevated three-quarter view, open walkable lane across the lower third, semi-realistic anime 2.5D render, cold white, blue-black and cyan palette, restrained amber private-memory accents, subtle digital fragment edges, crisp silhouettes, low visual noise. No characters, no UI, no readable text, no interactive evidence objects baked into the room.

逐场主体：

- 01：a long sterile consciousness corridor with five recessed door bays and a reflective dark glass floor
- 02：a memory archive room, photo display wall in the upper half and a family dining alcove in the lower half
- 03：an abandoned small indie game studio, dusty computer desks, shelves and unfinished handmade game prototypes
- 04：a symmetrical validation chamber, pristine successful office on the left, repaired failed creative studio on the right, empty central simulator platform
- 05：a quiet teenager bedroom at night, desk area on the left, doorway on the right, an empty wall reserved for a memory mirror
- 06：a dark consciousness surgery chamber with an empty central bed platform and five radial cable channels embedded in the floor

## 输出要求

- 房间：固定 1200×438 宽屏镜头，分别输出无角色、无文字、无交互物的背景。
- 道具：透明背景，正交友好的三分之四视角，完整物件不得裁边。
- 优先顺序：场景 03 插槽架 → 场景 06 手术台 → 场景 05 记忆镜 → 场景 04 模拟器 → 其余。
- 如果只能下载 3D 模型：保留 GLB/FBX 源文件，同时从固定镜头输出 PNG；Demo 先使用 PNG。
