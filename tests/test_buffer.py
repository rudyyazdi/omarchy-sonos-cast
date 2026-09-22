import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch


class BufferTests(unittest.TestCase):
    def setUp(self):
        self.runtime = tempfile.TemporaryDirectory()
        self.addCleanup(self.runtime.cleanup)
        path = Path(__file__).resolve().parents[1] / "sonos-cast"
        loader = importlib.machinery.SourceFileLoader("sonos_cast_test", str(path))
        self.app = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
        with patch.dict(os.environ, XDG_RUNTIME_DIR=self.runtime.name):
            loader.exec_module(self.app)
        self.app.LAT = 30

    def toggle(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.app.cmd_buffer_toggle()

    def test_default_off_and_invalid_preference(self):
        self.assertFalse(self.app.buffered())
        for value in ('broken', '[]', '{"enabled": "true"}'):
            Path(self.app.BUFFERFILE).write_text(value)
            self.assertFalse(self.app.buffered())

    def test_idle_toggle_does_not_start_playback(self):
        with patch.object(self.app, "casting", return_value=False), \
             patch.object(self.app, "av") as av, \
             patch.object(self.app, "sonos_play_stream") as play:
            self.toggle()
            self.assertTrue(self.app.buffered())
            self.toggle()
            self.assertFalse(self.app.buffered())
            av.assert_not_called()
            play.assert_not_called()

    def test_live_toggle_flushes_before_replay(self):
        actions = []
        with patch.object(self.app, "casting", return_value=True), \
             patch.object(self.app, "av", side_effect=lambda action: actions.append(action)), \
             patch.object(self.app, "sonos_play_stream", side_effect=lambda: actions.append("Play")):
            self.toggle()
            self.assertTrue(self.app.buffered())
            self.toggle()
            self.assertFalse(self.app.buffered())
        self.assertEqual(actions, ["Stop", "Play", "Stop", "Play"])

    def test_failed_reconnect_restores_previous_preference(self):
        with patch.object(self.app, "casting", return_value=True), \
             patch.object(self.app, "av"), \
             patch.object(self.app, "sonos_play_stream", side_effect=[OSError("unreachable"), None]) as play:
            with self.assertRaises(OSError):
                self.toggle()
            self.assertFalse(self.app.buffered())
            self.assertEqual(play.call_count, 2)

    def test_stopping_cast_keeps_buffer_choice(self):
        self.app.set_buffered(True)
        with patch.object(self.app, "server_alive", return_value=0), \
             patch.object(self.app, "sh", return_value=""), \
             patch.object(self.app, "osd"):
            self.app.cmd_off(stop_speaker=False)
        self.assertTrue(self.app.buffered())

    def test_stream_preserves_pcm_and_buffers_only_when_enabled(self):
        pcm = bytes(range(256)) * 1400
        for enabled in (False, True):
            with self.subTest(enabled=enabled), tempfile.TemporaryFile() as capture:
                self.app.set_buffered(enabled)
                capture.write(pcm)
                capture.seek(0)
                recorder = Mock(stdout=capture)
                output = io.BytesIO()
                writes = []
                def write(data):
                    writes.append(len(data))
                    return output.write(data)
                handler = object.__new__(self.app.Handler)
                handler.path = "/stream.wav"
                handler.connection = Mock()
                handler._head = Mock()
                handler.wfile = Mock(write=write)
                with patch.object(self.app.subprocess, "Popen", return_value=recorder) as popen:
                    handler.do_GET()
                self.assertEqual(output.getvalue()[:4], b"RIFF")
                self.assertEqual(output.getvalue()[44:], pcm)
                self.assertIn(f"--latency-msec={200 if enabled else 30}", popen.call_args.args[0])
                if enabled:
                    self.assertGreaterEqual(writes[1], 44100 * 4)
                else:
                    self.assertLessEqual(writes[1], 4096)
                recorder.terminate.assert_called_once()
                recorder.wait.assert_called_once_with(timeout=2)

    def test_status_exposes_buffer_choice(self):
        self.app.set_buffered(True)
        output = io.StringIO()
        with patch.object(self.app, "casting", return_value=False), \
             patch.object(self.app, "sonos_room", return_value="Office"), \
             patch.object(self.app, "sonos_state", return_value="STOPPED"), \
             patch.object(self.app, "sonos_volume", return_value=15), \
             patch.object(self.app, "sonos_muted", return_value=False), \
             contextlib.redirect_stdout(output):
            self.app.cmd_status(True)
        self.assertIs(json.loads(output.getvalue())["buffered"], True)


if __name__ == "__main__":
    unittest.main()
