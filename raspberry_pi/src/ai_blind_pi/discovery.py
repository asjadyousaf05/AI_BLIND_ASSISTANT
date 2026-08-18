"""Private-LAN mDNS advertisement for Flutter discovery."""

from __future__ import annotations

import ipaddress
import logging
import socket
from typing import Any

LOGGER = logging.getLogger(__name__)
SERVICE_TYPE = "_aiba-wearable._tcp.local."


class MdnsAdvertiser:
    def __init__(self, *, host: str, port: int, device_id: str, device_name: str):
        self.host = host
        self.port = port
        self.device_id = device_id
        self.device_name = device_name
        self._zeroconf: Any = None
        self._info: Any = None

    async def start(self) -> None:
        try:
            address = ipaddress.ip_address(self.host)
        except ValueError as error:
            raise RuntimeError(
                "mDNS requires AIBA_BIND_HOST to be a concrete IP address"
            ) from error
        if address.is_unspecified or address.is_loopback or not address.is_private:
            raise RuntimeError("mDNS is only advertised on a concrete private-LAN address")
        try:
            from zeroconf import IPVersion, ServiceInfo
            from zeroconf.asyncio import AsyncZeroconf
        except ImportError as error:
            raise RuntimeError("zeroconf dependency is unavailable") from error
        instance = self.device_name.replace(".", "-")[:40]
        self._info = ServiceInfo(
            SERVICE_TYPE,
            f"{instance}.{SERVICE_TYPE}",
            addresses=[socket.inet_aton(self.host)],
            port=self.port,
            properties={
                "deviceId": self.device_id,
                "deviceName": self.device_name,
                "protocolVersion": "1",
                "path": "/wearable/v1",
                "security": "hmac-sha256",
            },
            server=f"{instance}.local.",
        )
        self._zeroconf = AsyncZeroconf(ip_version=IPVersion.V4Only)
        await self._zeroconf.async_register_service(self._info)
        LOGGER.info("advertising %s on %s:%s", SERVICE_TYPE, self.host, self.port)

    async def close(self) -> None:
        if self._zeroconf is None:
            return
        try:
            if self._info is not None:
                await self._zeroconf.async_unregister_service(self._info)
        finally:
            await self._zeroconf.async_close()
            self._zeroconf = None
            self._info = None
