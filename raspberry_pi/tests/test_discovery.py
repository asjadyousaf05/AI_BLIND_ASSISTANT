from __future__ import annotations

import pytest

from ai_blind_pi.discovery import MdnsAdvertiser


@pytest.mark.asyncio
@pytest.mark.parametrize("registration_fails", [False, True])
async def test_advertisement_owns_only_selected_interface_and_cleans_up(
    monkeypatch, registration_fails: bool
) -> None:
    from zeroconf import IPVersion

    instances = []

    class FakeZeroconf:
        def __init__(self, **options):
            self.options = options
            self.closed = False
            self.unregistered = False
            instances.append(self)

        async def async_register_service(self, info, **options):
            self.info = info
            self.registration_options = options
            if registration_fails:
                raise OSError("simulated interface loss")

        async def async_unregister_service(self, info):
            self.unregistered = True

        async def async_close(self):
            self.closed = True

    monkeypatch.setattr("zeroconf.asyncio.AsyncZeroconf", FakeZeroconf)
    advertiser = MdnsAdvertiser(
        host="192.168.43.2",
        port=8765,
        device_id="pi-discovery-test",
        device_name="Test wearable",
    )
    if registration_fails:
        with pytest.raises(OSError, match="simulated interface loss"):
            await advertiser.start()
    else:
        await advertiser.start()
    instance = instances[0]
    assert instance.options == {"interfaces": ["192.168.43.2"], "ip_version": IPVersion.V4Only}
    assert instance.registration_options == {"allow_name_change": True}
    assert instance.info.properties[b"deviceId"] == b"pi-discovery-test"
    assert instance.info.properties[b"path"] == b"/wearable/v1"
    await advertiser.close()
    assert instance.closed
    assert instance.unregistered


@pytest.mark.asyncio
@pytest.mark.parametrize("host", ["0.0.0.0", "127.0.0.1", "8.8.8.8"])
async def test_discovery_rejects_non_private_lan_binding(host: str) -> None:
    advertiser = MdnsAdvertiser(host=host, port=8765, device_id="test", device_name="test")
    with pytest.raises(RuntimeError, match="concrete private-LAN"):
        await advertiser.start()
