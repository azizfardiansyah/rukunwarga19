from __future__ import annotations

import json
import tempfile
import urllib.request
import zipfile
from pathlib import Path


REPO_ZIP_URL = (
    "https://codeload.github.com/emsifa/api-wilayah-indonesia/zip/refs/heads/master"
)
OUTPUT_PATH = Path("assets/datasets/indonesia_regions.json")
USER_AGENT = "Mozilla/5.0"


def title_case_name(value: str) -> str:
    special_upper = {"DKI", "DI", "NAD", "NTB", "NTT", "DIY"}
    parts = value.strip().split()
    normalized: list[str] = []
    for part in parts:
        upper = part.upper()
        if upper in special_upper:
            normalized.append(upper)
        else:
            normalized.append(part.lower().capitalize())
    return " ".join(normalized)


def read_json_from_zip(zf: zipfile.ZipFile, name: str) -> list[dict[str, str]]:
    with zf.open(name) as handle:
        return json.load(handle)


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp_dir:
        archive_path = Path(tmp_dir) / "regions.zip"
        request = urllib.request.Request(
            REPO_ZIP_URL,
            headers={"User-Agent": USER_AGENT},
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            archive_path.write_bytes(response.read())

        with zipfile.ZipFile(archive_path) as zf:
            root = "api-wilayah-indonesia-master/static/api/"
            provinces = read_json_from_zip(zf, f"{root}provinces.json")

            regencies_by_province: dict[str, list[dict[str, str]]] = {}
            districts_by_regency: dict[str, list[dict[str, str]]] = {}
            villages_by_district: dict[str, list[dict[str, str]]] = {}

            normalized_provinces = [
                {"id": item["id"], "name": title_case_name(item["name"])}
                for item in provinces
            ]

            for province in provinces:
                province_id = province["id"]
                regencies = read_json_from_zip(
                    zf,
                    f"{root}regencies/{province_id}.json",
                )
                regencies_by_province[province_id] = [
                    {"id": item["id"], "name": title_case_name(item["name"])}
                    for item in regencies
                ]

                for regency in regencies:
                    regency_id = regency["id"]
                    districts = read_json_from_zip(
                        zf,
                        f"{root}districts/{regency_id}.json",
                    )
                    districts_by_regency[regency_id] = [
                        {"id": item["id"], "name": title_case_name(item["name"])}
                        for item in districts
                    ]

                    for district in districts:
                        district_id = district["id"]
                        villages = read_json_from_zip(
                            zf,
                            f"{root}villages/{district_id}.json",
                        )
                        villages_by_district[district_id] = [
                            {"id": item["id"], "name": title_case_name(item["name"])}
                            for item in villages
                        ]

        dataset = {
            "source": "https://github.com/emsifa/api-wilayah-indonesia",
            "provinces": normalized_provinces,
            "regenciesByProvince": regencies_by_province,
            "districtsByRegency": districts_by_regency,
            "villagesByDistrict": villages_by_district,
        }

        OUTPUT_PATH.write_text(
            json.dumps(dataset, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )

    print(f"Wrote dataset to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
