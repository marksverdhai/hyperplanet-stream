import importlib.machinery
import importlib.util
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
