import configparser
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


root = Path(__file__).resolve().parents[1]
package = root / "packages/native/kernora-desktop"
sys.path.insert(0, str(package / "tools"))
from kernora_design import COLOURS


def check_theme(theme):
    translucent = ET.parse(theme / "widgets/panel-background.svg").getroot()
    solid = ET.parse(theme / "solid/widgets/panel-background.svg").getroot()
    for image, opacity in ((translucent, "0.82"), (solid, "1")):
        elements = {element.get("id"): element for element in image.iter()}
        for prefix in ("", "thick-", "floating-"):
            for part in ("center", "top", "bottom", "left", "right", "topleft", "topright", "bottomleft", "bottomright"):
                element = elements[prefix + part]
                assert element.get("fill-opacity") == opacity, (theme, prefix, part)
                assert element.get("class") == "ColorScheme-Background"
        assert elements["mask-center"].get("fill") == "#000000"
        for corner in ("topleft", "topright", "bottomleft", "bottomright"):
            shadow = elements["shadow-" + corner]
            assert shadow.get("fill-rule") == "evenodd" and shadow.get("d").count("Z") == 2, (theme, corner)
        assert elements["shadow-top"].tag.endswith("g"), theme
    for image in (translucent, solid):
        for element in image.iter():
            element.attrib.pop("fill-opacity", None)
    assert ET.tostring(translucent) == ET.tostring(solid), theme
    settings = configparser.ConfigParser()
    settings.read(theme / "plasmarc")
    assert settings.getboolean("BlurBehindEffect", "enabled")
    assert not settings.getboolean("ContrastEffect", "enabled")
    assert settings.getboolean("AdaptiveTransparency", "enabled")
    tasks = {element.get("id"): element for element in ET.parse(theme / "widgets/tasks.svg").getroot().iter()}
    for state in ("normal-", "minimized-", "hover-", "launcher-hover-", "focus-", "focus-hover-", "attention-", "progress-"):
        corner = tasks[state + "topleft"]
        box, shape = list(corner)
        assert box.get("fill") == "none" and shape.tag.endswith("path"), (theme, state)
    for relative in ("dialogs/background.svg", "widgets/tooltip.svg"):
        image = ET.parse(theme / relative).getroot()
        assert next(element for element in image.iter() if element.get("id") == "center").get("fill-opacity") == "1"


with tempfile.TemporaryDirectory() as temporary:
    count = 0
    for generation in ("md1", "md2", "md3"):
        base = Path(temporary) / generation / "kernora"
        for colour in COLOURS:
            output = base if colour == "kernora" else base.parent / colour
            arguments = [sys.executable, str(package / "tools/gen-plasma-theme"), str(package / "data/symbols"), str(output)]
            if colour != "kernora":
                arguments.append(str(base))
            subprocess.run(arguments, check=True, stdout=subprocess.DEVNULL,
                           env={**os.environ, "KERNORA_GENERATION": generation, "KERNORA_COLOUR": colour})
            for theme in (output, output.with_name(output.name + "-light")):
                check_theme(theme)
                count += 1
    print(f"Panel transparency: {count} colour/style/mode variants OK")
