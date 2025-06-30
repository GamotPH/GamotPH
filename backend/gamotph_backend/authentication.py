# gamotph_backend/authentication.py

import jwt
from rest_framework.authentication import BaseAuthentication
from rest_framework import exceptions

class SupabaseUser:
    def __init__(self, payload):
        self.payload = payload

    @property
    def is_authenticated(self):
        return True

    def __str__(self):
        return self.payload.get('email', 'Unknown User')

class SupabaseJWTAuthentication(BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')

        if not auth_header:
            return None

        try:
            token_type, token = auth_header.split(' ')
            if token_type.lower() != 'bearer':
                raise exceptions.AuthenticationFailed('Invalid token header.')
        except ValueError:
            raise exceptions.AuthenticationFailed('Invalid token header.')

        try:
            decoded = jwt.decode(
                token,
                options={"verify_signature": False},  # Warning: no signature check
                algorithms=["HS256"]
            )
        except jwt.PyJWTError:
            raise exceptions.AuthenticationFailed('Invalid token.')

        user = SupabaseUser(decoded)
        return (user, None)
