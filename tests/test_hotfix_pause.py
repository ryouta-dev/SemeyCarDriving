"""Source-contract regressions only; not a Godot execution test."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[1]
class PauseHotfixTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT/'scripts/semey_world_manager.gd').read_text(encoding="utf-8")
    def function(self, name):
        pattern = r'^func '+re.escape(name)+r'\([^\n]*\) -> void:\n(.*?)(?=^func |\Z)'
        match = re.search(pattern, self.source, re.M|re.S)
        self.assertIsNotNone(match, name)
        return match.group(1)
    def test_notification_does_not_mutate_tree(self):
        body = self.function('_notification')
        self.assertNotIn('add_child(', body)
        self.assertNotIn('paused = true', body)
        self.assertIn('_pause_for_resume()', body)
    def test_pause_request_is_deferred_and_deduplicated(self):
        body = self.function('_pause_for_resume')
        self.assertIn('_pause_requested', body)
        self.assertIn('_apply_pause_for_resume.call_deferred()', body)
        self.assertNotIn('add_child(', body)
    def test_deferred_handler_has_lifecycle_guards(self):
        body = self.function('_apply_pause_for_resume')
        for guard in ['is_inside_tree()', 'is_queued_for_deletion()', '_leaving_world', 'is_node_ready()', '_spawning']:
            self.assertIn(guard, body)
        self.assertLess(body.index('add_child(pause_layer)'), body.index('get_tree().paused = true'))
    def test_resume_checks_controls_and_exit_cancels_pause(self):
        body = self.function('_resume_after_focus_loss')
        self.assertIn('is_instance_valid(mobile_controls)', body)
        self.assertIn('get_tree().paused = false', body)
        self.assertIn('_leaving_world = true', self.function('open_garage'))
