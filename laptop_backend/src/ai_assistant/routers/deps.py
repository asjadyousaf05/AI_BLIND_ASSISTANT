"""FastAPI dependency: extract and verify bearer token → user_id."""

from __future__ import annotations

from fastapi import HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

_bearer = HTTPBearer(auto_error=False)


async def get_current_user(request: Request) -> str:
    """Verify Authorization header and return the authenticated user_id.

    Raises HTTP 401 if the token is missing, invalid, or expired.
    Never logs the token value.
    """
    credentials: HTTPAuthorizationCredentials | None = await _bearer(request)
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header.",
        )

    auth_service = request.app.state.auth_service
    user_id = auth_service.verify_token(credentials.credentials)

    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token. Please re-pair the device.",
        )

    return user_id
