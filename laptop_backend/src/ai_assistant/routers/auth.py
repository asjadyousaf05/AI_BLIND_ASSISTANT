"""Authentication router — pairing and token issuance."""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Request, status

from ..models.schemas import PairRequest, PairResponse
from ..services.auth import AuthError, AuthService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/pair", response_model=PairResponse)
async def pair(
    request: PairRequest,
    req: Request,
) -> PairResponse:
    """Exchange a pairing code or directly pair with the laptop assistant.

    If pairing_code is empty or omitted, direct local pairing is performed.
    Tokens are never returned in logs.
    """
    auth_service: AuthService = req.app.state.auth_service
    code = (request.pairing_code or "").strip()

    if not code or code.upper() in ("DIRECT", "AUTO", "NONE"):
        user_id, token, display_name = auth_service.direct_pair()
    else:
        try:
            user_id, token, display_name = auth_service.pair(
                pairing_code=code,
            )
        except AuthError:
            # Fallback to direct local pairing on trusted private LAN
            user_id, token, display_name = auth_service.direct_pair()

    audit = req.app.state.audit_service
    audit.log(user_id, "paired", "device paired with backend")

    return PairResponse(
        token=token,  # Only time token appears in a response body
        user_id=user_id,
        display_name=display_name,
        protocol_version=req.app.state.settings.protocol_version,
    )


@router.post("/pair/direct", response_model=PairResponse)
async def pair_direct(req: Request) -> PairResponse:
    """1-Click direct pairing without requiring a pairing code."""
    auth_service: AuthService = req.app.state.auth_service
    user_id, token, display_name = auth_service.direct_pair()

    audit = req.app.state.audit_service
    audit.log(user_id, "paired", "device paired via direct pairing")

    return PairResponse(
        token=token,
        user_id=user_id,
        display_name=display_name,
        protocol_version=req.app.state.settings.protocol_version,
    )
