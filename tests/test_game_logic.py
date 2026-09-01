import ast
from pathlib import Path


GAME_FILE = Path(__file__).resolve().parents[1] / "U11-Final CPT.py"


def load_function(function_name):
    """
    Loads a single function from the game source without executing
    the full Pygame Zero application.
    """
    source = GAME_FILE.read_text(encoding="utf-8")
    tree = ast.parse(source)

    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == function_name:
            module = ast.Module(body=[node], type_ignores=[])
            namespace = {}
            exec(compile(module, str(GAME_FILE), "exec"), namespace)
            return namespace[function_name]

    raise AssertionError(f"Function {function_name} was not found")


def test_game_file_exists():
    assert GAME_FILE.exists()


def test_game_source_is_valid_python():
    source = GAME_FILE.read_text(encoding="utf-8")
    ast.parse(source)


def test_selection_sorting_descending():
    selection_sorting = load_function("selection_sorting")

    scores = [10, 50, 20, 100, 30]

    result = selection_sorting(scores)

    assert result == [100, 50, 30, 20, 10]


def test_selection_sorting_empty_list():
    selection_sorting = load_function("selection_sorting")

    assert selection_sorting([]) == []


def test_selection_sorting_single_score():
    selection_sorting = load_function("selection_sorting")

    assert selection_sorting([50]) == [50]


def test_selection_sorting_duplicate_scores():
    selection_sorting = load_function("selection_sorting")

    scores = [50, 100, 50, 25, 100]

    result = selection_sorting(scores)

    assert result == [100, 100, 50, 50, 25]