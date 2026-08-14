import importlib.machinery
import importlib.util
import sys
from pathlib import Path


def load_script(name: str, path: Path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    loader.exec_module(module)
    return module


ROOT = Path(__file__).resolve().parents[1]
overlay = load_script("terminal_overlay", ROOT / "bin/hyperplanet-terminal-overlay")


def test_truecolor_and_block_cells_survive_parsing():
    rows = overlay.parse_ansi("\x1b[38;2;1;2;3m▀▄█")
    assert [cell.char for cell in rows[0]] == ["▀", "▄", "█"]
    assert all(cell.fg == (1, 2, 3) for cell in rows[0])


def test_secret_values_are_redacted():
    rows = overlay.parse_ansi("YT_STREAMKEY=do-not-publish ghp_also-private")
    overlay.redact_rows(rows)
    plain = "".join(cell.char for cell in rows[0])
    assert "do-not-publish" not in plain
    assert "also-private" not in plain
    assert "[REDACTED]" in plain
