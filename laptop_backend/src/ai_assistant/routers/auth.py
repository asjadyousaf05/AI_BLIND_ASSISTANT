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
    """Exchange a valid, one-time owner pairing code for a bearer token."""
    auth_service: AuthService = req.app.state.auth_service
    code = (request.pairing_code or "").strip()

    try:
        user_id, token, display_name = auth_service.pair(pairing_code=code)
    except AuthError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired pairing code.",
        ) from error

    audit = req.app.state.audit_service
    audit.log(user_id, "paired", "device paired with backend")

    return PairResponse(
        token=token,  # Only time token appears in a response body
        user_id=user_id,
        display_name=display_name,
        protocol_version=req.app.state.settings.protocol_version,
    )
