"""Tests for MCP server adapter — no subprocess, tests arg-building logic directly."""
import sys, os, subprocess, unittest
from unittest.mock import patch, MagicMock

# Add mcp dir to path so we can import server
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'mcp'))


class TestRun(unittest.TestCase):
    def setUp(self):
        import server as s
        self.server = s

    def test_run_builds_correct_args(self):
        """_run passes all kwargs as --key value pairs."""
        captured = {}
        def fake_run(args, **kwargs):
            captured['args'] = args
            m = MagicMock()
            m.stdout = 'result'
            return m
        with patch('subprocess.run', fake_run):
            self.server._run('user', count=3, format='json')
        self.assertIn('--count', captured['args'])
        self.assertIn('3', captured['args'])
        self.assertIn('--format', captured['args'])
        self.assertIn('json', captured['args'])

    def test_run_skips_none_kwargs(self):
        """_run omits kwargs with None values."""
        captured = {}
        def fake_run(args, **kwargs):
            captured['args'] = args
            m = MagicMock()
            m.stdout = 'result'
            return m
        with patch('subprocess.run', fake_run):
            self.server._run('number', min=None, max=50)
        self.assertNotIn('--min', captured['args'])
        self.assertIn('--max', captured['args'])
        self.assertIn('50', captured['args'])

    def test_run_returns_error_string_on_failure(self):
        """_run returns ERROR: string when bash exits non-zero."""
        def fake_run(args, **kwargs):
            e = subprocess.CalledProcessError(2, args)
            e.stderr = 'seed_cart: --format sql is not supported'
            raise e
        with patch('subprocess.run', fake_run):
            result = self.server._run('cart', format='sql')
        self.assertTrue(result.startswith('ERROR:'))

    def test_seed_user_tool_exists(self):
        """seed_user is registered as an MCP tool."""
        self.assertTrue(hasattr(self.server, 'seed_user'))
        self.assertTrue(callable(self.server.seed_user))

    def test_seed_date_passes_from_to(self):
        """seed_date maps from_date/to_date to --from/--to flags."""
        captured = {}
        def fake_run(args, **kwargs):
            captured['args'] = args
            m = MagicMock()
            m.stdout = '2022-05-10'
            return m
        with patch('subprocess.run', fake_run):
            self.server.seed_date(from_date='2020-01-01', to_date='2023-12-31')
        self.assertIn('--from', captured['args'])
        self.assertIn('2020-01-01', captured['args'])
        self.assertIn('--to', captured['args'])

    def test_seed_lorem_passes_words(self):
        """seed_lorem passes --words flag."""
        captured = {}
        def fake_run(args, **kwargs):
            captured['args'] = args
            m = MagicMock()
            m.stdout = 'lorem ipsum'
            return m
        with patch('subprocess.run', fake_run):
            self.server.seed_lorem(words=5)
        self.assertIn('--words', captured['args'])
        self.assertIn('5', captured['args'])
        self.assertNotIn('--sentences', captured['args'])

    def test_new_tools_registered(self):
        """All 7 new tools are registered as callable attributes."""
        for name in ('seed_coordinates', 'seed_country', 'seed_credit_card',
                     'seed_log_entry', 'seed_error_log', 'seed_api_key',
                     'seed_db_credentials'):
            self.assertTrue(hasattr(self.server, name), f"{name} not found")
            self.assertTrue(callable(getattr(self.server, name)), f"{name} not callable")

    def test_seed_api_key_passes_prefix(self):
        """seed_api_key maps prefix param to --prefix flag."""
        captured = {}
        def fake_run(args, **kwargs):
            captured['args'] = args
            m = MagicMock()
            m.stdout = 'pk_abc123'
            return m
        with patch('subprocess.run', fake_run):
            self.server.seed_api_key(prefix='pk_')
        self.assertIn('--prefix', captured['args'])
        self.assertIn('pk_', captured['args'])

    def test_seed_api_key_omits_prefix_when_none(self):
        """seed_api_key omits --prefix when not provided."""
        captured = {}
        def fake_run(args, **kwargs):
            captured['args'] = args
            m = MagicMock()
            m.stdout = 'sk_abc123'
            return m
        with patch('subprocess.run', fake_run):
            self.server.seed_api_key()
        self.assertNotIn('--prefix', captured['args'])


    def test_seed_custom_tool_exists(self):
        """seed_custom is registered as an MCP tool."""
        self.assertTrue(hasattr(self.server, 'seed_custom'))
        self.assertTrue(callable(self.server.seed_custom))

    def test_seed_custom_passes_schema(self):
        """seed_custom maps schema param to --schema flag."""
        captured = {}
        def fake_run(args, **kwargs):
            captured['args'] = args
            m = MagicMock()
            m.stdout = '{}'
            return m
        with patch('subprocess.run', fake_run):
            self.server.seed_custom(schema='example')
        self.assertIn('--schema', captured['args'])
        self.assertIn('example', captured['args'])


if __name__ == '__main__':
    unittest.main()
