# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Read the installed OptMemo once for OMP, without transport pagination."""

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import subprocess
import sys


def snapshot(memo_path):
    loader = importlib.machinery.SourceFileLoader("optmemo_omp_reader", memo_path)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    module.ME = subprocess.list2cmdline([sys.executable, memo_path])
    directory = module.memory_dir()
    if not os.path.isfile(module.log_path(directory)) or not os.path.isdir(
        os.path.join(directory, "TREE")
    ):
        raise FileNotFoundError("Existing OptMemo LOG.txt and TREE/ are required: " + directory)

    output, errors = io.StringIO(), io.StringIO()
    status, count = "ready", None
    with module.locked(directory):
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            try:
                module.config(directory)
                # Keep WAKE_LINES and all compression rules. Only remove the
                # tool-output transport cap within this short-lived process.
                module.PART_CHARS = sys.maxsize
                module.PART_LINES = sys.maxsize
                count = module.log_len(directory)
                module.cmd_wake(directory, [])
            except SystemExit as exc:
                if exc.code not in (None, 0):
                    status = "blocked" if output.getvalue().startswith("Cannot wake:") else "error"

    text = output.getvalue().rstrip()
    if errors.getvalue().strip():
        text += "\n" + errors.getvalue().strip()
    if status == "ready" and "You are awake." not in text.splitlines():
        status = "error"
    return {"status": status, "count": count, "text": text, "memoryDir": directory}


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("Usage: wake.py <installed-memo-path>")
        result = snapshot(os.path.abspath(sys.argv[1]))
    except Exception as exc:
        result = {"status": "error", "count": None, "text": str(exc), "memoryDir": None}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
