import io
import uuid
import zipfile
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from models.case import Case
from models.user import User
from models.attachment import Attachment
from models.audit import AuditLog
from models.enums import UserRole, CaseStatus, CaseType, CasePriority
from core.security import create_access_token
from providers.storage import set_storage_provider
from providers.storage.local import LocalStorageProvider


def make_token(user: User) -> str:
    token, _ = create_access_token(str(user.id), user.email, user.role.value)
    return token


def create_sample_docx_bytes() -> bytes:
    """Generate a minimal valid OpenXML .docx in memory."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", '<?xml version="1.0" encoding="UTF-8"?><Types></Types>')
        zf.writestr("word/document.xml", '<?xml version="1.0" encoding="UTF-8"?><w:document></w:document>')
    return buf.getvalue()


@pytest.fixture(autouse=True)
def setup_local_storage(tmp_path):
    """Ensure tests run against an isolated local storage directory."""
    provider = LocalStorageProvider(base_dir=str(tmp_path / "test_uploads"))
    set_storage_provider(provider)
    yield provider
    set_storage_provider(None)


@pytest.mark.asyncio
async def test_upload_valid_png_attachment(async_client: AsyncClient, test_db):
    """Verify uploading a valid PNG file succeeds, generates UUID path, and logs audit record."""
    user = User(
        email="requester1@example.com",
        password_hash="dummy_hash",
        role=UserRole.REQUESTER,
        email_verified=True,
    )
    test_db.add(user)
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000100",
        type=CaseType.INCIDENT,
        title="Screen flicker issue",
        description="Monitor flickers randomly.",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=user.id,
        version=1,
    )
    test_db.add(case)
    await test_db.commit()

    token = make_token(user)

    # Valid PNG binary header
    png_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4"
    files = {"file": ("screenshot.png", png_bytes, "image/png")}

    response = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files=files,
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 201
    data = response.json()
    assert data["file_name"] == "screenshot.png"
    assert data["file_type"] == "image/png"
    assert data["file_size"] == len(png_bytes)
    assert data["case_id"] == str(case.id)
    assert data["uploaded_by"] == str(user.id)
    assert data["uploader_email"] == user.email

    # UUID storage path per SRS §7.5
    assert data["storage_path"].startswith(f"cases/{case.id}/")
    assert data["storage_path"].endswith(".png")

    # Verify AuditLog recorded
    stmt = select(AuditLog).where(
        AuditLog.target_id == case.id,
        AuditLog.action == "ATTACHMENT_UPLOADED",
    )
    res = await test_db.execute(stmt)
    audit = res.scalar_one_or_none()
    assert audit is not None
    assert audit.actor_id == user.id
    assert audit.after_value["attachment_id"] == data["id"]
    assert audit.after_value["file_name"] == "screenshot.png"


@pytest.mark.asyncio
async def test_upload_valid_pdf_and_docx(async_client: AsyncClient, test_db):
    """Verify PDF and DOCX uploads succeed with appropriate MIME identification."""
    user = User(
        email="req_docs@example.com",
        password_hash="dummy_hash",
        role=UserRole.REQUESTER,
        email_verified=True,
    )
    test_db.add(user)
    await test_db.flush()

    case = Case(
        reference_number="REQ-2026-000101",
        type=CaseType.SERVICE_REQUEST,
        title="Software license request",
        description="Need license documentation.",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=user.id,
        version=1,
    )
    test_db.add(case)
    await test_db.commit()

    token = make_token(user)

    # 1. PDF Upload
    pdf_bytes = b"%PDF-1.5\n%Header content\n%%EOF"
    pdf_res = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("invoice.pdf", pdf_bytes, "application/pdf")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert pdf_res.status_code == 201
    assert pdf_res.json()["file_type"] == "application/pdf"

    # 2. DOCX Upload
    docx_bytes = create_sample_docx_bytes()
    docx_res = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("specs.docx", docx_bytes, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert docx_res.status_code == 201
    assert "wordprocessingml" in docx_res.json()["file_type"]


@pytest.mark.asyncio
async def test_reject_disallowed_extension(async_client: AsyncClient, test_db):
    """Verify non-allowlisted extensions (.exe, .sh, .py, .zip) are rejected."""
    user = User(email="req_bad@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000102",
        type=CaseType.INCIDENT,
        title="Test disallowed",
        description="Test description",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=user.id,
    )
    test_db.add(case)
    await test_db.commit()
    token = make_token(user)

    bad_files = [
        ("malware.exe", b"MZ\x90\x00\x03\x00\x00\x00"),
        ("script.sh", b"#!/bin/bash\necho hello"),
        ("source.py", b"print('hello world')"),
        ("data.zip", b"PK\x03\x04\x00\x00\x00\x00"),
    ]

    for name, content in bad_files:
        res = await async_client.post(
            f"/api/v1/cases/{case.id}/attachments",
            files={"file": (name, content, "application/octet-stream")},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "UNSUPPORTED_FILE_TYPE"


@pytest.mark.asyncio
async def test_reject_spoofed_extension(async_client: AsyncClient, test_db):
    """Verify magic bytes validation detects and rejects spoofed extensions (e.g. EXE renamed to PNG)."""
    user = User(email="req_spoof@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000103",
        type=CaseType.INCIDENT,
        title="Test spoofed",
        description="Test description",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=user.id,
    )
    test_db.add(case)
    await test_db.commit()
    token = make_token(user)

    # Windows PE executable renamed to .png
    fake_png = b"MZ\x90\x00\x03\x00\x00\x00This is an executable payload"
    res = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("innocent.png", fake_png, "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 400
    assert res.json()["error"]["code"] in ("DISALLOWED_FILE_TYPE", "INVALID_FILE_SIGNATURE")


@pytest.mark.asyncio
async def test_reject_file_exceeding_10mb(async_client: AsyncClient, test_db):
    """Verify single files larger than 10MB are rejected per SRS §7.5."""
    user = User(email="req_large@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000104",
        type=CaseType.INCIDENT,
        title="Test large",
        description="Test description",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=user.id,
    )
    test_db.add(case)
    await test_db.commit()
    token = make_token(user)

    # 10MB + 10 bytes text file
    large_bytes = b"A" * (10 * 1024 * 1024 + 10)
    res = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("huge.log", large_bytes, "text/plain")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 413
    assert res.json()["error"]["code"] == "FILE_TOO_LARGE"


@pytest.mark.asyncio
async def test_case_quota_and_50mb_limit(async_client: AsyncClient, test_db):
    """Verify cumulative case quota tracking and rejection when 50MB threshold is exceeded."""
    user = User(email="req_quota@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000105",
        type=CaseType.INCIDENT,
        title="Test quota",
        description="Test description",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=user.id,
    )
    test_db.add(case)
    await test_db.commit()
    token = make_token(user)

    # 1. Initial quota check
    quota_res = await async_client.get(
        f"/api/v1/cases/{case.id}/attachments/quota",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert quota_res.status_code == 200
    q_data = quota_res.json()
    assert q_data["used_bytes"] == 0
    assert q_data["attachment_count"] == 0
    assert q_data["remaining_bytes"] == 50 * 1024 * 1024

    # 2. Simulate existing attachments summing to 48MB
    att1 = Attachment(
        case_id=case.id,
        file_name="existing_dump.log",
        storage_path=f"cases/{case.id}/existing.log",
        file_type="text/plain",
        file_size=48 * 1024 * 1024,
        uploaded_by=user.id,
    )
    test_db.add(att1)
    await test_db.commit()

    # Quota check should show 48MB used
    quota_res2 = await async_client.get(
        f"/api/v1/cases/{case.id}/attachments/quota",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert quota_res2.json()["used_bytes"] == 48 * 1024 * 1024
    assert quota_res2.json()["attachment_count"] == 1

    # 3. Attempting to upload 5MB file should fail (48MB + 5MB = 53MB > 50MB)
    five_mb_txt = b"B" * (5 * 1024 * 1024)
    fail_res = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("overflow.log", five_mb_txt, "text/plain")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert fail_res.status_code == 400
    assert fail_res.json()["error"]["code"] == "CASE_ATTACHMENT_QUOTA_EXCEEDED"


@pytest.mark.asyncio
async def test_requester_isolation_and_staff_access(async_client: AsyncClient, test_db):
    """Verify Requesters can only access attachments for their own cases, while Staff can access all."""
    req1 = User(email="req_owner@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    req2 = User(email="req_stranger@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    operator = User(email="operator@example.com", password_hash="dummy_hash", role=UserRole.OPERATOR, email_verified=True)
    test_db.add_all([req1, req2, operator])
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000106",
        type=CaseType.INCIDENT,
        title="Owner case",
        description="Owner description",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=req1.id,
    )
    test_db.add(case)
    await test_db.commit()

    token1 = make_token(req1)
    token2 = make_token(req2)
    token_op = make_token(operator)

    # 1. Req1 uploads attachment
    txt_bytes = b"Application error log content line 1\nline 2"
    up_res = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("error.log", txt_bytes, "text/plain")},
        headers={"Authorization": f"Bearer {token1}"},
    )
    assert up_res.status_code == 201
    att_id = up_res.json()["id"]

    # 2. Req2 attempts to list attachments on Req1's case -> 403 Forbidden
    list_res = await async_client.get(
        f"/api/v1/cases/{case.id}/attachments",
        headers={"Authorization": f"Bearer {token2}"},
    )
    assert list_res.status_code == 403
    assert list_res.json()["error"]["code"] == "PERMISSION_DENIED"

    # 3. Req2 attempts to get attachment metadata directly -> 403 Forbidden
    get_res = await async_client.get(
        f"/api/v1/attachments/{att_id}",
        headers={"Authorization": f"Bearer {token2}"},
    )
    assert get_res.status_code == 403

    # 4. Operator can view attachment metadata and list case attachments
    op_list_res = await async_client.get(
        f"/api/v1/cases/{case.id}/attachments",
        headers={"Authorization": f"Bearer {token_op}"},
    )
    assert op_list_res.status_code == 200
    assert len(op_list_res.json()) == 1


@pytest.mark.asyncio
async def test_download_and_delete_attachment(async_client: AsyncClient, test_db):
    """Verify presigned download URL generation and deletion workflows."""
    user = User(email="req_dl@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000107",
        type=CaseType.INCIDENT,
        title="Download test case",
        description="Testing download link",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=user.id,
    )
    test_db.add(case)
    await test_db.commit()
    token = make_token(user)

    txt_bytes = b"Server crash diagnostics trace"
    up_res = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("crash.log", txt_bytes, "text/plain")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert up_res.status_code == 201
    att_id = up_res.json()["id"]

    # 1. Request presigned download URL
    dl_res = await async_client.get(
        f"/api/v1/attachments/{att_id}/download?expires_in=1800",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert dl_res.status_code == 200
    dl_data = dl_res.json()
    assert dl_data["attachment_id"] == att_id
    assert "download_url" in dl_data
    assert dl_data["expires_in_seconds"] == 1800

    # 2. Delete attachment
    del_res = await async_client.delete(
        f"/api/v1/attachments/{att_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert del_res.status_code == 204

    # 3. Verify attachment no longer exists
    get_after = await async_client.get(
        f"/api/v1/attachments/{att_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_after.status_code == 404

    # 4. Verify ATTACHMENT_DELETED AuditLog entry
    stmt = select(AuditLog).where(
        AuditLog.target_id == case.id,
        AuditLog.action == "ATTACHMENT_DELETED",
    )
    res = await test_db.execute(stmt)
    audit = res.scalar_one_or_none()
    assert audit is not None
    assert audit.before_value["attachment_id"] == att_id


@pytest.mark.asyncio
async def test_idempotent_attachment_upload(async_client: AsyncClient, test_db):
    """Verify Idempotency-Key header prevents duplicate file uploads per SRS §3.6."""
    user = User(email="req_idem@example.com", password_hash="dummy_hash", role=UserRole.REQUESTER, email_verified=True)
    test_db.add(user)
    await test_db.flush()

    case = Case(
        reference_number="INC-2026-000108",
        type=CaseType.INCIDENT,
        title="Idempotency test",
        description="Testing idempotency header",
        status=CaseStatus.NEW,
        priority=CasePriority.P3,
        requester_id=user.id,
    )
    test_db.add(case)
    await test_db.commit()
    token = make_token(user)

    txt_bytes = b"Unique log trace for idempotency test"
    idem_key = f"upload-key-{uuid.uuid4()}"

    # First attempt
    res1 = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("trace.log", txt_bytes, "text/plain")},
        headers={
            "Authorization": f"Bearer {token}",
            "Idempotency-Key": idem_key,
        },
    )
    assert res1.status_code == 201
    data1 = res1.json()

    # Retry attempt with identical Idempotency-Key
    res2 = await async_client.post(
        f"/api/v1/cases/{case.id}/attachments",
        files={"file": ("trace.log", txt_bytes, "text/plain")},
        headers={
            "Authorization": f"Bearer {token}",
            "Idempotency-Key": idem_key,
        },
    )
    assert res2.status_code == 201
    data2 = res2.json()

    # Must return the same attachment ID rather than creating a duplicate
    assert data1["id"] == data2["id"]
    assert data1["storage_path"] == data2["storage_path"]

    # Verify only 1 Attachment row exists in database
    stmt = select(Attachment).where(Attachment.case_id == case.id)
    att_rows = (await test_db.execute(stmt)).scalars().all()
    assert len(att_rows) == 1
