"""Read-only dump recovery checks; run separately from real-device scenarios."""
import subprocess
import unittest
from unittest.mock import patch

from android_ui import AndroidUI


class DumpRecovery(unittest.TestCase):
    def error(self, code):
        return subprocess.CalledProcessError(code, ['adb', 'shell', 'uiautomator dump'],
                                             output='UI hierchary dumped to: stale.xml')

    @patch('android_ui.time.sleep')
    def test_killed_dump_is_discarded_before_fresh_read(self, _):
        ui = AndroidUI()
        with patch.object(ui, 'shell', side_effect=[
            '', self.error(137), '', 'UI hierchary dumped to: fresh.xml',
            '<hierarchy><node text="fresh"/></hierarchy>',
        ]) as shell:
            self.assertEqual('fresh', ui.dump().find('node').get('text'))
            self.assertEqual([
                'rm -f /sdcard/e2e-window.xml', 'uiautomator dump /sdcard/e2e-window.xml',
                'rm -f /sdcard/e2e-window.xml', 'uiautomator dump /sdcard/e2e-window.xml',
                'cat /sdcard/e2e-window.xml',
            ], [call.args[0] for call in shell.call_args_list])

    @patch('android_ui.time.sleep')
    def test_repeated_kills_remain_a_failure(self, _):
        ui = AndroidUI()
        with patch.object(ui, 'shell', side_effect=['', self.error(137)] * 3) as shell:
            with self.assertRaises(subprocess.CalledProcessError):
                ui.dump()
            self.assertEqual(6, shell.call_count)

    def test_other_command_errors_are_not_retried(self):
        ui = AndroidUI()
        with patch.object(ui, 'shell', side_effect=['', self.error(1)]) as shell:
            with self.assertRaises(subprocess.CalledProcessError):
                ui.dump()
            self.assertEqual(2, shell.call_count)


if __name__ == '__main__':
    unittest.main(verbosity=2)
