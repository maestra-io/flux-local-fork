"""Tests for the git source controller helpers."""

from unittest.mock import MagicMock

import pytest

from flux_local.source_controller.git import GitError, _checkout


def test_checkout_rejects_option_shaped_ref() -> None:
    """A ref starting with '-' never reaches git."""
    repo = MagicMock()
    with pytest.raises(GitError, match="option-shaped"):
        _checkout(repo, "--pathspec-from-file=/etc/passwd")
    repo.git.checkout.assert_not_called()


def test_checkout_passes_plain_ref() -> None:
    """A normal branch name is checked out."""
    repo = MagicMock()
    _checkout(repo, "main")
    repo.git.checkout.assert_called_once_with("main")
