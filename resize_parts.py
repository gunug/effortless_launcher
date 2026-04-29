"""parts 폴더 내 이미지를 512x512로 리사이징."""
from pathlib import Path
from PIL import Image

PARTS_DIR = Path(__file__).parent / "parts"
OUTPUT_DIR = PARTS_DIR / "resized"
SIZE = (512, 512)
EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}


def main() -> None:
    if not PARTS_DIR.exists():
        raise SystemExit(f"폴더 없음: {PARTS_DIR}")

    OUTPUT_DIR.mkdir(exist_ok=True)

    files = [p for p in PARTS_DIR.iterdir() if p.is_file() and p.suffix.lower() in EXTS]
    if not files:
        print("리사이징할 이미지가 없습니다.")
        return

    for src in files:
        with Image.open(src) as img:
            resized = img.resize(SIZE, Image.LANCZOS)
            dst = OUTPUT_DIR / f"{src.stem}_512{src.suffix}"
            resized.save(dst)
        print(f"OK  {src.name}  ->  {dst.relative_to(PARTS_DIR)}")

    print(f"\n완료: {len(files)}개 파일 -> {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
