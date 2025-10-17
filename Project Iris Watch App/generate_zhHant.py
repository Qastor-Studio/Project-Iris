import json
import opencc
from pathlib import Path

# 初始化繁简转换器（简体 -> 繁体）
converter = opencc.OpenCC('s2t.json')

# 修改这里的文件路径（你的 xcstrings 文件）
input_path = Path("Localizable.xcstrings")
output_path = Path("Localizable_with_zhHant.xcstrings")

# 读取原始文件
with open(input_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# 遍历每个字符串
for key, value in data.get("strings", {}).items():
    locs = value.get("localizations")
    if not isinstance(locs, dict):
        continue

    hans = locs.get("zh-Hans")
    if not hans:
        continue

    # 获取简体中文文本
    hans_value = hans.get("stringUnit", {}).get("value", "")
    if not hans_value:
        continue

    # 如果 zh-Hant 不存在则创建
    if "zh-Hant" not in locs:
        hant_value = converter.convert(hans_value)
        locs["zh-Hant"] = {
            "stringUnit": {
                "state": "translated",
                "value": hant_value
            }
        }

# 写回新文件
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"✅ 已生成 zh-Hant 内容，输出文件：{output_path}")
