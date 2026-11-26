"""Phase-one fixture oracle. Supports only primitives and alias chains used here.

This is neither a general WIT canonicalizer nor the WITProbe compatibility engine.
It removes allocation IDs before comparing the actual three parser outputs.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def semantic_model(resolve):
    def ty(value, seen=()):
        if value is None or isinstance(value, str):
            return value
        if not isinstance(value, int) or isinstance(value, bool):
            raise ValueError(f"unsupported fixture type: {value!r}")
        if value in seen:
            raise ValueError("cyclic type alias")
        kind = resolve["types"][value]["kind"]
        if set(kind) != {"type"}:
            raise ValueError(f"unsupported fixture type kind: {kind!r}")
        return ty(kind["type"], seen + (value,))

    def interface_name(index):
        interface = resolve["interfaces"][index]
        package = resolve["packages"][interface["package"]]["name"]
        return package + "/" + interface["name"]

    def function(value):
        return {
            "name": value["name"],
            "kind": value["kind"],
            "params": [(param["name"], ty(param["type"])) for param in value["params"]],
            "result": ty(value.get("result")),
        }

    def edges(items):
        output = []
        for key, item in items.items():
            if "interface" not in item:
                raise ValueError("fixture expected interface edge")
            identity = interface_name(item["interface"]["id"])
            output.append(identity if key.startswith("interface-") else key + ":" + identity)
        return sorted(output)

    return {
        "packages": sorted(package["name"] for package in resolve["packages"]),
        "interfaces": {
            interface_name(index): {
                "functions": {name: function(f) for name, f in interface["functions"].items()},
                "types": {name: ty(index) for name, index in interface["types"].items()},
            }
            for index, interface in enumerate(resolve["interfaces"])
        },
        "worlds": {
            resolve["packages"][world["package"]]["name"] + "/" + world["name"]: {
                "imports": edges(world["imports"]),
                "exports": edges(world["exports"]),
            }
            for world in resolve["worlds"]
        },
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-dir", type=Path, default=ROOT / "evidence")
    evidence = parser.parse_args().evidence_dir.resolve()
    moon = read_json(evidence / "resolved-fixtures.json")
    rows = []
    for case in ("v1", "v2", "dependency"):
        actual = semantic_model(moon[case]["resolve"])
        expected = semantic_model(read_json(evidence / f"official-{case}.json"))
        if actual != expected:
            raise AssertionError(f"semantic mismatch in {case}: {actual!r} != {expected!r}")
        selected = moon[case]["resolve"]["worlds"][moon[case]["world_id"]]
        if selected["name"] != "calculator-world":
            raise AssertionError(f"wrong selected world in {case}: {selected['name']}")
        rows.append({"case": case, "status": "PASS", "normalized": actual})
    (evidence / "fixture-semantic-comparison.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Fixture semantic comparison: {len(rows)}/{len(rows)} PASS (primitive aliases, functions, worlds, packages)")


if __name__ == "__main__":
    main()
