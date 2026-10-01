import os
import datetime
import hashlib
import jwt
from typing import Optional
from fastapi import Request, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import User

SECRET_KEY = os.getenv("SECRET_KEY", "mandi_erp_secret_key_super_secure_jwt_2026")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30

def hash_password(password: str) -> str:
    salt = "mandi_system_salt_2026"
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 100000).hex()

def verify_password(password: str, hashed_password: str) -> bool:
    return hash_password(password) == hashed_password

def create_session_token(user_id: int) -> str:
    """Generates a signed JWT token containing user_id and expiration."""
    expire = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "user_id": user_id,
        "exp": expire
    }
    encoded_jwt = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_token(token: str) -> Optional[int]:
    """Decodes and validates a JWT token. Returns user_id if valid, None if invalid/expired."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("user_id")
        return user_id
    except jwt.PyJWTError:
        return None

def get_current_user_optional(request: Request, db: Session = Depends(get_db)) -> Optional[User]:
    """
    Retrieves current logged-in user from:
    1. 'Authorization: Bearer <token>' Header (Mobile / REST API)
    2. 'session_token' Cookie (Web UI)
    """
    token = None
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
    
    if not token:
        token = request.cookies.get("session_token")

    if not token:
        return None

    user_id = decode_token(token)
    if not user_id:
        return None

    user = db.query(User).filter(User.id == user_id).first()
    return user

def get_current_user(request: Request, db: Session = Depends(get_db)) -> User:
    """Dependency that ensures user is logged in. Returns User or raises 401."""
    user = get_current_user_optional(request, db)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Ghair tasdeeq shuda request! Baraye meharbani pehle login karein.",
            headers={"WWW-Authenticate": "Bearer"}
        )
    return user
