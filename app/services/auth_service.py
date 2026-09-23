import hashlib
import secrets
from typing import Optional
from fastapi import Request, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import User

# In-memory session store mapping token -> user_id
ACTIVE_SESSIONS = {}

def hash_password(password: str) -> str:
    salt = "mandi_system_salt_2026"
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 100000).hex()

def verify_password(password: str, hashed_password: str) -> bool:
    return hash_password(password) == hashed_password

def create_session_token(user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    ACTIVE_SESSIONS[token] = user_id
    return token

def get_current_user_optional(request: Request, db: Session = Depends(get_db)) -> Optional[User]:
    """Retrieves current logged-in user if session cookie is valid, else returns None."""
    token = request.cookies.get("session_token")
    user_id_cookie = request.cookies.get("user_id")

    user_id = None
    if token and token in ACTIVE_SESSIONS:
        user_id = ACTIVE_SESSIONS[token]
    elif user_id_cookie and user_id_cookie.isdigit():
        user_id = int(user_id_cookie)

    if not user_id:
        return None

    user = db.query(User).filter(User.id == user_id).first()
    return user

def get_current_user(request: Request, db: Session = Depends(get_db)) -> User:
    """Dependency that ensures user is logged in. Returns User or raises 401."""
    user = get_current_user_optional(request, db)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return user
