import io
import os
import re
import zipfile
from typing import Tuple, Optional
from fastapi import HTTPException, status


# Allowed file extensions per SRS §7.5
ALLOWED_EXTENSIONS = {
    "jpg",
    "jpeg",
    "png",
    "webp",
    "gif",
    "pdf",
    "docx",
    "txt",
    "log",
}

# Mapping of file extensions to canonical MIME types
EXTENSION_TO_MIME = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
    "gif": "image/gif",
    "pdf": "application/pdf",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "txt": "text/plain",
    "log": "text/plain",
}

# Dangerous executable magic headers to categorically reject
DISALLOWED_BINARY_HEADERS = [
    (b"\x7fELF", "ELF executable binary"),
    (b"MZ", "Windows PE executable / DLL"),
    (b"\xca\xfe\xba\xbe", "Mach-O universal binary / Java bytecode"),
    (b"\xce\xfa\xed\xfe", "Mach-O 32-bit binary"),
    (b"\xcf\xfa\xed\xfe", "Mach-O 64-bit binary"),
    (b"\xfe\xed\xfa\xce", "Mach-O 32-bit reverse binary"),
    (b"\xfe\xed\xfa\xcf", "Mach-O 64-bit reverse binary"),
    (b"Rar!\x1a\x07\x00", "RAR archive"),
    (b"7z\xbc\xaf\x27\x1c", "7-Zip archive"),
]

# Max constraints per SRS §7.5
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10MB
MAX_CASE_ATTACHMENTS_SIZE_BYTES = 50 * 1024 * 1024  # 50MB


def sanitize_filename(filename: str) -> str:
    """
    Sanitize an uploaded file name to remove path traversal sequences,
    control characters, and unsafe characters.
    """
    if not filename:
        return "unnamed_file"
    # Take only the base name (strip directory traversal)
    base = os.path.basename(filename).strip()
    # Replace dangerous or control characters with underscore
    safe = re.sub(r'[^a-zA-Z0-9._\- ]', '_', base)
    # Collapse multiple spaces or dots
    safe = re.sub(r'\.{2,}', '.', safe)
    safe = safe.strip(" ._")
    return safe or "unnamed_file"


def verify_magic_bytes(extension: str, file_bytes: bytes) -> str:
    """
    Verify that binary content matches the expected file type according
    to its magic number signatures per SRS §7.5.
    Returns the verified MIME type or raises HTTPException.
    """
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": {
                    "code": "EMPTY_FILE",
                    "message": "Uploaded file is empty (0 bytes).",
                    "details": {},
                }
            },
        )

    # Check against known malicious binary headers first
    for header, desc in DISALLOWED_BINARY_HEADERS:
        if file_bytes.startswith(header):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "DISALLOWED_FILE_TYPE",
                        "message": f"Uploaded file contains executable or disallowed binary header ({desc}).",
                        "details": {"detected_header": desc},
                    }
                },
            )

    header_16 = file_bytes[:16]

    if extension in ("jpg", "jpeg"):
        # JPEG begins with \xff\xd8\xff
        if not file_bytes.startswith(b"\xff\xd8\xff"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_FILE_SIGNATURE",
                        "message": "File extension is JPEG but content lacks valid JPEG signature.",
                        "details": {"expected": "image/jpeg"},
                    }
                },
            )
        return "image/jpeg"

    elif extension == "png":
        # PNG signature: \x89PNG\r\n\x1a\n
        if not file_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_FILE_SIGNATURE",
                        "message": "File extension is PNG but content lacks valid PNG signature.",
                        "details": {"expected": "image/png"},
                    }
                },
            )
        return "image/png"

    elif extension == "gif":
        # GIF signature: GIF87a or GIF89a
        if not (file_bytes.startswith(b"GIF87a") or file_bytes.startswith(b"GIF89a")):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_FILE_SIGNATURE",
                        "message": "File extension is GIF but content lacks valid GIF signature.",
                        "details": {"expected": "image/gif"},
                    }
                },
            )
        return "image/gif"

    elif extension == "webp":
        # WebP signature: RIFF at 0..4, WEBP at 8..12
        if len(file_bytes) < 12 or not (file_bytes[:4] == b"RIFF" and file_bytes[8:12] == b"WEBP"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_FILE_SIGNATURE",
                        "message": "File extension is WEBP but content lacks valid WebP signature.",
                        "details": {"expected": "image/webp"},
                    }
                },
            )
        return "image/webp"

    elif extension == "pdf":
        # PDF signature: %PDF-
        if not file_bytes.startswith(b"%PDF-"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_FILE_SIGNATURE",
                        "message": "File extension is PDF but content lacks valid PDF signature.",
                        "details": {"expected": "application/pdf"},
                    }
                },
            )
        return "application/pdf"

    elif extension == "docx":
        # DOCX is an OpenXML Zip package starting with PK\x03\x04
        if not file_bytes.startswith(b"PK\x03\x04"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_FILE_SIGNATURE",
                        "message": "File extension is DOCX but content is not a valid zip container.",
                        "details": {"expected": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"},
                    }
                },
            )
        # Inspect zip contents to confirm it is actually an Office OpenXML document
        try:
            with zipfile.ZipFile(io.BytesIO(file_bytes)) as zf:
                namelist = zf.namelist()
                has_content_types = "[Content_Types].xml" in namelist
                has_word_dir = any(name.startswith("word/") for name in namelist)
                if not (has_content_types and has_word_dir):
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail={
                            "error": {
                                "code": "INVALID_FILE_SIGNATURE",
                                "message": "File is a zip archive but lacks Word document structure ([Content_Types].xml / word/).",
                                "details": {},
                            }
                        },
                    )
        except zipfile.BadZipFile:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_FILE_SIGNATURE",
                        "message": "File extension is DOCX but archive is corrupted or unreadable.",
                        "details": {},
                    }
                },
            )
        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

    elif extension in ("txt", "log"):
        # Plain text / log: Must be valid text without null bytes or binary control characters
        # Disallow null bytes (typical indicator of binary payload or shellcode)
        if b"\x00" in file_bytes[:4096]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_FILE_SIGNATURE",
                        "message": "Plain text/log file contains binary null bytes.",
                        "details": {},
                    }
                },
            )
        # Must be decodable as UTF-8 or Latin-1
        try:
            file_bytes.decode("utf-8")
        except UnicodeDecodeError:
            try:
                file_bytes.decode("latin-1")
            except Exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={
                        "error": {
                            "code": "INVALID_FILE_SIGNATURE",
                            "message": "Text/log file could not be decoded as UTF-8 or Latin-1.",
                            "details": {},
                        }
                    },
                )
        return "text/plain"

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail={
            "error": {
                "code": "UNSUPPORTED_FILE_TYPE",
                "message": f"File extension '{extension}' is not supported.",
                "details": {"allowed_extensions": list(ALLOWED_EXTENSIONS)},
            }
        },
    )


def validate_file(
    file_name: str,
    file_bytes: bytes,
    declared_content_type: Optional[str] = None,
) -> Tuple[str, str, int]:
    """
    Validate an uploaded file against extension allowlist, file size limits,
    and magic-bytes signatures.
    
    Returns:
        Tuple of (sanitized_file_name, verified_mime_type, file_size_bytes)
    """
    safe_name = sanitize_filename(file_name)
    
    # Extract extension
    parts = safe_name.rsplit(".", 1)
    if len(parts) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": {
                    "code": "MISSING_FILE_EXTENSION",
                    "message": "File name must include a valid extension.",
                    "details": {"allowed_extensions": list(ALLOWED_EXTENSIONS)},
                }
            },
        )
    
    ext = parts[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": {
                    "code": "UNSUPPORTED_FILE_TYPE",
                    "message": f"File type '.{ext}' is not permitted. Only {', '.join(sorted(ALLOWED_EXTENSIONS))} are allowed.",
                    "details": {"allowed_extensions": sorted(list(ALLOWED_EXTENSIONS))},
                }
            },
        )

    file_size = len(file_bytes)
    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": {
                    "code": "EMPTY_FILE",
                    "message": "Uploaded file is empty (0 bytes).",
                    "details": {},
                }
            },
        )

    if file_size > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=getattr(status, "HTTP_413_CONTENT_TOO_LARGE", 413),
            detail={
                "error": {
                    "code": "FILE_TOO_LARGE",
                    "message": f"File size exceeds maximum allowed limit of {MAX_FILE_SIZE_BYTES // (1024*1024)}MB.",
                    "details": {
                        "size_bytes": file_size,
                        "max_bytes": MAX_FILE_SIZE_BYTES,
                    },
                }
            },
        )

    verified_mime = verify_magic_bytes(ext, file_bytes)
    return safe_name, verified_mime, file_size
