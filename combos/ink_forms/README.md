# 墨势六式

先制定 [出招表与节奏表](design.md)，再实现独立水墨绘制。共六式七击：探锋、折枝、三点雨、绞云、悬笔、断江。独立演示，不引用 Homing Star 游戏代码或资源。

打开本仓库的 `project.godot`，在画廊选择「墨势六式 · 起承转合」；或打开本目录 `ink_forms.tscn` 按 F6。1/空格重放，2 切换四分之一速，R 清空重置，Esc 返回画廊。

实时预览：../../media/ink_forms.gif；半速预览：../../media/ink_forms_halfspeed.gif；整体逐帧：../../media/ink_forms_sheet.png；局部细节：../../media/ink_forms_detail.png。

## 实现

`style.json` 的 `renderer: "ink"` 选择 `vfx/ink_stage.gd`，沿用开源项目事件时钟、击退、顿帧、按键与录帧流程。`vfx/ink_stroke.gd` 独立绘制压力笔腹、淡墨边缘、飞白和墨滴。原有样例仍使用原渲染器。

该场景中 `slash` 增加 `ink_kind`：`dry` 干笔、`elbow` 折笔、`dot` 短刺（`tilt` 在此表示起笔纵向偏移）、`coil` 开放螺旋、`fall` 竖落。`width` 为笔宽；`charge` 改为收墨；`hit` 改为接触洇墨，终结额外绘制触地泼墨。路径在出笔时取当前目标位置，固定在舞台空间，残墨不会随攻击者滑动。此示例未使用普通月牙、星芒、光环或屏幕闪白。

角色仍为原项目的抽象攻击标记和目标木桩；没有制作角色动作或伤害碰撞系统。参数默认中文、细线纤维、纸色背景、地面技能链，不套用预设 ink 调色板。

## 验证

```powershell
python tools/verify_combo.py ink_forms --gif --keep-frames --godot <Godot控制台程序路径>
godot --headless --path . --script res://tools/verify_ink_forms.gd
```

实测：`PASS: 7 hits landed`；形态、顿帧冻结、重置、重放、四分之一速与残墨清理检查通过。原有 `ember_launcher` 回归自检：`PASS: 5 hits landed`。已检查整体逐帧和三点雨、悬笔、断江的放大细节；实时与半速 GIF 已输出。
