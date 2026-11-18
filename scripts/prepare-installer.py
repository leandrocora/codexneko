#!/usr/bin/env python3
"""Prepare a native product installer with update checks and a close-app prompt."""
import argparse
import plistlib
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("app", type=Path)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("--finalize", action="store_true")
    args = parser.parse_args()
    info = plistlib.loads((args.app / "Contents/Info.plist").read_bytes())
    version, build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
    if not all(re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", value) for value in [version, build]):
        raise SystemExit("Installer versions must contain only numeric components")
    workspace = args.workspace
    workspace.mkdir(parents=True, exist_ok=True)
    scripts = workspace / "Scripts"
    if not args.finalize:
        scripts.mkdir(exist_ok=True)
        for name in ["preinstall", "postinstall", "common.sh"]:
            shutil.copy2(Path(__file__).parent / "installer" / name, scripts / name)
            (scripts / name).chmod(0o755 if name != "common.sh" else 0o644)
        (scripts / "Version.plist").write_bytes(plistlib.dumps({
            "CFBundleShortVersionString": version, "CFBundleVersion": build,
        }))
        (workspace / "Requirements.plist").write_bytes(plistlib.dumps({"arch": ["arm64"], "os": ["13.0"]}))
        (workspace / "PackageVersion.txt").write_text(version + "." + build)
        return
    component = workspace / "CodexNekoComponent.pkg"
    distribution = workspace / "Distribution.xml"
    subprocess.run(["/usr/bin/productbuild", "--synthesize", "--product", str(workspace / "Requirements.plist"),
                    "--package", str(component), str(distribution)], check=True)
    tree = ET.parse(distribution)
    root = tree.getroot()
    title = root.find("title")
    if title is None:
        title = ET.SubElement(root, "title")
    title.text = "CodexNeko — Instalação e atualização"
    domains = root.find("domains")
    if domains is None:
        domains = ET.SubElement(root, "domains")
    domains.attrib.update(enable_anywhere="false", enable_currentUserHome="false", enable_localSystem="true")
    options = root.find("options")
    if options is not None:
        options.set("customize", "never")
    reference = ET.SubElement(root, "pkg-ref", {"id": "com.coradini.multicodex.installer"})
    must_close = ET.SubElement(reference, "must-close")
    ET.SubElement(must_close, "app", {"id": "com.coradini.multicodex.manager"})
    for kind, filename in [("welcome", "Welcome.html"), ("conclusion", "Conclusion.html")]:
        ET.SubElement(root, kind, {"file": filename, "mime-type": "text/html"})
    tree.write(distribution, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
