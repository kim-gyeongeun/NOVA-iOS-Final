from pathlib import Path
import stat
import pytest
from setup_keys import read_config, save_config


def test_save_uses_private_permissions(tmp_path):
    f = tmp_path / '.env'
    save_config({'OPENAI_API_KEY': 'test-secret-placeholder-only'}, f)
    assert read_config(f)['OPENAI_API_KEY'] == 'test-secret-placeholder-only'
    assert stat.S_IMODE(f.stat().st_mode) == 0o600
    assert 'test-secret-placeholder-only' not in (tmp_path / 'not-created').name


def test_newline_rejected(tmp_path):
    with pytest.raises(ValueError):
        save_config({'OPENAI_API_KEY': 'bad\nSOMETHING=1'}, tmp_path / '.env')


def test_no_file_means_no_keys(tmp_path):
    assert read_config(tmp_path / '.env') == {}
