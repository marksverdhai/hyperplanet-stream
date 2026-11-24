import importlib.machinery
import importlib.util
import time
import sys
from pathlib import Path
from types import SimpleNamespace


ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "bin/hyperplanet-youtube-listener"
loader = importlib.machinery.SourceFileLoader("youtube_listener", str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
listener = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = listener
loader.exec_module(listener)


TRUSTED = "UC0000000000000000000000"


def message(channel=TRUSTED, moderator=True):
    author = SimpleNamespace(channelId=channel, isChatModerator=moderator)
    return SimpleNamespace(
        id="message-1", type="textMessage", message="test", author=author
    )


def test_requires_exact_channel_and_moderator_badge():
    assert listener.authorized_text(message(), TRUSTED) == ("test", "authorized")
    assert listener.authorized_text(
        message(channel="UC1111111111111111111111"), TRUSTED
    )[1] == "author-channel-mismatch"
    assert listener.authorized_text(
        message(moderator=False), TRUSTED
    )[1] == "not-current-moderator"


def test_acknowledgement_config_is_bounded_and_control_free():
    config = {"acknowledgement": {"enabled": True, "message": "HAI received."}}
    assert listener.acknowledgement_message(config) == "HAI received."
    assert listener.acknowledgement_message({}) is None

    for invalid in ("", "x\n", "x" * 201):
        config["acknowledgement"]["message"] = invalid
        try:
            listener.acknowledgement_message(config)
        except ValueError:
            pass
        else:
            raise AssertionError(f"accepted invalid acknowledgement: {invalid!r}")


def test_acknowledgement_uses_minimal_environment(monkeypatch, tmp_path):
    calls = []

    def fake_run(command, **kwargs):
        calls.append((command, kwargs))
        return SimpleNamespace(returncode=0, stdout="", stderr="")

    monkeypatch.setattr(listener.subprocess, "run", fake_run)
    monkeypatch.setattr(listener, "CONFIG_DIR", tmp_path / "config")
    monkeypatch.setenv("HYPERPLANET_BIN_DIR", str(tmp_path / "bin"))
    monkeypatch.setenv("HYPERPLANET_YOUTUBE_CHAT_PYTHON", "/trusted/python")
    listener.acknowledge(
        {"acknowledgement": {"enabled": True, "message": "HAI received."}}
    )

    command, kwargs = calls[0]
    assert command == [
        "/trusted/python",
        str(tmp_path / "bin" / "hyperplanet-youtube-chat"),
        "send",
        "HAI received.",
    ]
    assert kwargs["env"] == {
        "HOME": str(Path.home()),
        "HYPERPLANET_CONFIG_DIR": str(tmp_path / "config"),
        "PATH": "/usr/bin:/bin",
    }


def test_conversational_turn_requests_response_without_delivery_metadata():
    rendered = listener.conversational_turn('hello "HAI"\nsecond line')

    assert "Authenticated YouTube live-chat message" in rendered
    assert "respond now" in rendered
    assert "do not merely acknowledge" in rendered
    assert 'message_json="hello \\"HAI\\"\\nsecond line"' in rendered
    assert "channel_id" not in rendered
    assert "delivery_marker" not in rendered


def test_trusted_message_is_delivered_and_acknowledged_once(monkeypatch, tmp_path):
    state_file = tmp_path / "listener-state.json"
    monkeypatch.setattr(listener, "STATE_FILE", state_file)
    delivered = []
    acknowledged = []
    monkeypatch.setattr(listener, "deliver", lambda target, text: delivered.append((target, text)))
    monkeypatch.setattr(listener, "acknowledge", lambda config: acknowledged.append(config))

    item = message()
    item.timestamp = int(time.time() * 1000)

    class Result:
        def sync_items(self):
            return [item]

    class Chat:
        def get(self):
            return Result()

    config = {
        "trustedModerator": {"channelId": TRUSTED},
        "directorTarget": "hai",
        "acknowledgement": {"enabled": True, "message": "HAI received."},
        "polling": {"minimumIntervalMillis": 2000},
    }
    state = {"schemaVersion": 1, "seenIds": []}
    started = int(time.time() * 1000)
    listener.poll_once(Chat(), config, state, started)
    listener.poll_once(Chat(), config, state, started)

    assert delivered == [("hai", listener.conversational_turn("test"))]
    assert acknowledged == [config]
