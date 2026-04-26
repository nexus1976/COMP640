-- For PostgreSQL 18+; uses gen_random_uuid() from pgcrypto for UUID generation.
CREATE TABLE clinic_location (
    location_id     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(120) NOT NULL,
    address_line1   VARCHAR(160) NOT NULL,
    address_line2   VARCHAR(160),
    city            VARCHAR(80)  NOT NULL,
    state           CHAR(2)      NOT NULL,
    zip_code        VARCHAR(10)  NOT NULL,
    phone           VARCHAR(20),
    email           VARCHAR(120),
    timezone        VARCHAR(60)  NOT NULL DEFAULT 'America/Los_Angeles',
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE room (
    room_id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id     UUID        NOT NULL REFERENCES clinic_location(location_id) ON DELETE CASCADE,
    room_number     VARCHAR(20) NOT NULL,
    room_type       VARCHAR(60) NOT NULL,          -- e.g. 'exam', 'imaging', 'lab', 'procedure'
    capacity        SMALLINT    NOT NULL DEFAULT 1,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (location_id, room_number)
);

CREATE TABLE patient (
    patient_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name          VARCHAR(80)  NOT NULL,
    last_name           VARCHAR(80)  NOT NULL,
    date_of_birth       DATE         NOT NULL,
    sex                 CHAR(1)      CHECK (sex IN ('M', 'F')),
    email               VARCHAR(256) UNIQUE,
    phone               VARCHAR(20),
    address_line1       VARCHAR(160),
    address_line2       VARCHAR(160),
    city                VARCHAR(80),
    state               CHAR(2),
    zip_code            VARCHAR(10),
    insurance_provider  VARCHAR(120),
    insurance_member_id VARCHAR(60),
    insurance_group_id  VARCHAR(60),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE doctor (
    doctor_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name      VARCHAR(80) NOT NULL,
    last_name       VARCHAR(80) NOT NULL,
    specialty       VARCHAR(120),
    license_number  VARCHAR(60) UNIQUE,
    email           VARCHAR(256) UNIQUE NOT NULL,
    phone           VARCHAR(20),
    location_id     UUID        REFERENCES clinic_location(location_id) ON DELETE SET NULL,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE doctor_availability (
    availability_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id       UUID        NOT NULL REFERENCES doctor(doctor_id) ON DELETE CASCADE,
    location_id     UUID        NOT NULL REFERENCES clinic_location(location_id) ON DELETE CASCADE,
    day_of_week     SMALLINT    NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0 = Sunday
    slot_start      TIME        NOT NULL,
    slot_end        TIME        NOT NULL,
    slot_date       DATE, 
    is_booked       BOOLEAN     NOT NULL DEFAULT FALSE,
    is_blocked      BOOLEAN     NOT NULL DEFAULT FALSE, 
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (slot_end > slot_start)
);
CREATE INDEX idx_availability_doctor ON doctor_availability(doctor_id);
CREATE INDEX idx_availability_date   ON doctor_availability(slot_date);

CREATE TABLE service (
    service_id      UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(120)   NOT NULL,
    description     TEXT,
    service_type    VARCHAR(60)    NOT NULL,  -- e.g.   'consultation', 'blood test', 'imaging', 'procedure', etc.
    duration_mins   SMALLINT       NOT NULL DEFAULT 30,
    base_price      NUMERIC(10,2)  NOT NULL DEFAULT 0.00,
    cpt_code        VARCHAR(10),
    is_active       BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE TABLE appointment (
    appointment_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          UUID         NOT NULL REFERENCES patient(patient_id) ON DELETE RESTRICT,
    doctor_id           UUID         NOT NULL REFERENCES doctor(doctor_id)  ON DELETE RESTRICT,
    location_id         UUID         NOT NULL REFERENCES clinic_location(location_id) ON DELETE RESTRICT,
    room_id             UUID         REFERENCES room(room_id) ON DELETE SET NULL, -- NULL for telehealth
    scheduled_at        TIMESTAMPTZ  NOT NULL,
    duration_mins       SMALLINT     NOT NULL DEFAULT 30,
    appointment_type    VARCHAR(20)  NOT NULL DEFAULT 'in_person' CHECK (appointment_type IN ('in_person', 'telehealth')),
    status              VARCHAR(30)  NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','confirmed','in_progress','completed','cancelled','no_show')),
    telehealth_url      TEXT,
    chief_complaint     TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    -- Telehealth appointments must not have a room; in-person appointments should have one.
    CONSTRAINT chk_room_telehealth CHECK (
        (appointment_type = 'telehealth' AND room_id IS NULL) OR (appointment_type = 'in_person')
    )
);
CREATE INDEX idx_appointment_patient   ON appointment(patient_id);
CREATE INDEX idx_appointment_doctor    ON appointment(doctor_id);
CREATE INDEX idx_appointment_scheduled ON appointment(scheduled_at);

CREATE TABLE appointment_service (
    appointment_service_id  UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id          UUID           NOT NULL REFERENCES appointment(appointment_id) ON DELETE CASCADE,
    service_id              UUID           NOT NULL REFERENCES service(service_id) ON DELETE RESTRICT,
    quantity                SMALLINT       NOT NULL DEFAULT 1,
    unit_price              NUMERIC(10,2)  NOT NULL,
    notes                   TEXT,
    created_at              TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    UNIQUE (appointment_id, service_id)
);

CREATE TABLE prescription (
    prescription_id     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          UUID        NOT NULL REFERENCES patient(patient_id) ON DELETE RESTRICT,
    doctor_id           UUID        NOT NULL REFERENCES doctor(doctor_id)   ON DELETE RESTRICT,
    appointment_id      UUID        REFERENCES appointment(appointment_id)  ON DELETE SET NULL,
    medication_name     VARCHAR(160) NOT NULL,
    dosage              VARCHAR(80)  NOT NULL,   -- e.g. '500mg'
    frequency           VARCHAR(80)  NOT NULL,   -- e.g. 'twice daily'
    route               VARCHAR(60),             -- e.g. 'oral', 'topical'
    quantity            VARCHAR(40),             -- e.g. '30 tablets'
    refills             SMALLINT     NOT NULL DEFAULT 0,
    instructions        TEXT,
    issued_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_prescription_patient ON prescription(patient_id);
CREATE INDEX idx_prescription_doctor  ON prescription(doctor_id);

CREATE TABLE lab_order (
    lab_order_id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          UUID        NOT NULL REFERENCES patient(patient_id) ON DELETE RESTRICT,
    doctor_id           UUID        NOT NULL REFERENCES doctor(doctor_id)   ON DELETE RESTRICT,
    appointment_id      UUID        REFERENCES appointment(appointment_id)  ON DELETE SET NULL,
    test_name           VARCHAR(160) NOT NULL,
    test_code           VARCHAR(100), 
    priority            VARCHAR(20)  NOT NULL DEFAULT 'routine' CHECK (priority IN ('routine','urgent','stat')),
    status              VARCHAR(30)  NOT NULL DEFAULT 'ordered' CHECK (status IN ('ordered','specimen_collected','in_progress','resulted','cancelled')),
    ordered_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    resulted_at         TIMESTAMPTZ,
    result_summary      TEXT,
    result_document_url TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_lab_order_patient ON lab_order(patient_id);
CREATE INDEX idx_lab_order_doctor  ON lab_order(doctor_id);

-- invoice
--    One invoice per appointment (policy: 1-to-1 per appointment, but the FK is not UNIQUE to allow re-billing scenarios).
-- ============================================================
CREATE TABLE invoice (
    invoice_id          UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id      UUID           NOT NULL REFERENCES appointment(appointment_id) ON DELETE RESTRICT,
    patient_id          UUID           NOT NULL REFERENCES patient(patient_id)         ON DELETE RESTRICT,
    subtotal            NUMERIC(10,2)  NOT NULL DEFAULT 0.00,
    discount            NUMERIC(10,2)  NOT NULL DEFAULT 0.00,
    tax                 NUMERIC(10,2)  NOT NULL DEFAULT 0.00,
    total_amount        NUMERIC(10,2)  NOT NULL DEFAULT 0.00,
    amount_paid         NUMERIC(10,2)  NOT NULL DEFAULT 0.00,
    status              VARCHAR(30)    NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','issued','partially_paid','paid','voided','collections')),
    issued_at           TIMESTAMPTZ,
    due_date            DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_invoice_appointment ON invoice(appointment_id);
CREATE INDEX idx_invoice_patient     ON invoice(patient_id);

CREATE TABLE payment (
    payment_id          UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id          UUID           NOT NULL REFERENCES invoice(invoice_id) ON DELETE RESTRICT,
    amount              NUMERIC(10,2)  NOT NULL CHECK (amount > 0),
    payment_method      VARCHAR(40)    NOT NULL CHECK (payment_method IN ('cash','credit_card','debit_card','check','insurance','ach','other')),
    payment_date        TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    transaction_ref     VARCHAR(120),
    notes               TEXT,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_payment_invoice ON payment(invoice_id);

CREATE TABLE insurance_claim (
    claim_id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id          UUID           NOT NULL REFERENCES invoice(invoice_id) ON DELETE RESTRICT,
    patient_id          UUID           NOT NULL REFERENCES patient(patient_id) ON DELETE RESTRICT,
    payer_name          VARCHAR(120)   NOT NULL,
    payer_id            VARCHAR(60), 
    member_id           VARCHAR(60)    NOT NULL,
    group_id            VARCHAR(60),
    claim_number        VARCHAR(80),
    submitted_at        TIMESTAMPTZ,
    adjudicated_at      TIMESTAMPTZ,
    status              VARCHAR(40)    NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','submitted','acknowledged','approved','denied','appealed','paid','void')),
    approved_amount     NUMERIC(10,2),
    denied_amount       NUMERIC(10,2),
    denial_reason       TEXT,
    notes               TEXT,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_claim_invoice ON insurance_claim(invoice_id);
CREATE INDEX idx_claim_patient ON insurance_claim(patient_id);

CREATE TABLE feedback (
    feedback_id     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id      UUID        NOT NULL REFERENCES patient(patient_id)     ON DELETE RESTRICT,
    appointment_id  UUID        NOT NULL REFERENCES appointment(appointment_id) ON DELETE CASCADE,
    doctor_id       UUID        REFERENCES doctor(doctor_id) ON DELETE SET NULL,
    rating          SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment         TEXT,
    is_anonymous    BOOLEAN     NOT NULL DEFAULT FALSE,
    reviewed_by     UUID        REFERENCES doctor(doctor_id) ON DELETE SET NULL,
    reviewed_at     TIMESTAMPTZ,
    review_notes    TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (patient_id, appointment_id) 
);
CREATE INDEX idx_feedback_appointment ON feedback(appointment_id);
CREATE INDEX idx_feedback_doctor      ON feedback(doctor_id);

/*
-- ============================================================
-- VIEWS  (convenience — not required but useful)
-- ============================================================

-- Outstanding balance per patient
CREATE VIEW v_patient_balance AS
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    SUM(i.total_amount - i.amount_paid) AS outstanding_balance
FROM patient p
JOIN invoice i ON i.patient_id = p.patient_id
WHERE i.status NOT IN ('voided','paid')
GROUP BY p.patient_id, patient_name;

-- Upcoming appointments with doctor and location info
CREATE VIEW v_upcoming_appointments AS
SELECT
    a.appointment_id,
    a.scheduled_at,
    a.appointment_type,
    a.status,
    p.first_name || ' ' || p.last_name   AS patient_name,
    d.first_name || ' ' || d.last_name   AS doctor_name,
    cl.name                               AS location_name,
    r.room_number
FROM appointment a
JOIN patient        p  ON p.patient_id   = a.patient_id
JOIN doctor         d  ON d.doctor_id    = a.doctor_id
JOIN clinic_location cl ON cl.location_id = a.location_id
LEFT JOIN room      r  ON r.room_id      = a.room_id
WHERE a.scheduled_at > NOW()
  AND a.status NOT IN ('cancelled','no_show')
ORDER BY a.scheduled_at;
*/

-- ============================================================
-- Clinic Schema — Business Rules Change Script
-- Target:  PostgreSQL 18+
-- Rules:
--   BizRule-1  Telehealth appointments must not assign a room
--   BizRule-2  Invoice total = SUM(services) - discount + tax
--   BizRule-3  Payment cannot exceed remaining invoice balance
-- ============================================================

-- ============================================================
-- BizRule-1  TELEHEALTH APPOINTMENTS MUST NOT ASSIGN A ROOM
-- ============================================================
-- The existing constraint name is chk_room_telehealth.  We drop
-- and re-add it with a cleaner name and tighter wording so the
-- error message is human-readable in logs.
-- ============================================================

BEGIN;

-- 1a. Replace the existing check constraint with an explicitly named, clearly messaged version.
ALTER TABLE appointment DROP CONSTRAINT IF EXISTS chk_room_telehealth;

ALTER TABLE appointment
    ADD CONSTRAINT chk_telehealth_no_room CHECK (
        NOT (appointment_type = 'telehealth' AND room_id IS NOT NULL)
    );
COMMENT ON CONSTRAINT chk_telehealth_no_room ON appointment IS 'BizRule-1: Telehealth appointments must not assign a room.';

-- 1b. Trigger function: when appointment_type is set to 'telehealth', automatically null out room_id so callers that patch only the type column are handled gracefully.
CREATE OR REPLACE FUNCTION trg_fn_clear_room_for_telehealth()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.appointment_type = 'telehealth' AND NEW.room_id IS NOT NULL THEN
        -- For room_id to NULL when appointment_type is set to telehealth.  If the room_id was already NULL, we leave it as is (idempotent).
        NEW.room_id := NULL;
        NEW.telehealth_url := COALESCE(NEW.telehealth_url, OLD.telehealth_url);
    END IF;

    -- Conversely, if switching FROM telehealth to in_person, clear the telehealth URL so stale video links are not left behind.
    IF NEW.appointment_type = 'in_person' AND OLD.appointment_type = 'telehealth' THEN
        NEW.telehealth_url := NULL;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_clear_room_for_telehealth ON appointment;

CREATE TRIGGER trg_clear_room_for_telehealth
    BEFORE INSERT OR UPDATE OF appointment_type, room_id
    ON appointment
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_clear_room_for_telehealth();
COMMENT ON FUNCTION trg_fn_clear_room_for_telehealth() IS 'BizRule-1: Telehealth appointments must not assign a room.';

COMMIT;


-- ============================================================
-- BizRule-2  INVOICE TOTAL = SUM(services) - DISCOUNT + TAX
-- ============================================================
-- Strategy: keep the existing denormalised columns (subtotal,
-- discount, tax, total_amount) for fast reads and reporting,
-- but enforce consistency through:
--
--   Step A — a trigger on appointment_service that recomputes
--             invoice.subtotal and invoice.total_amount whenever
--             a service line is inserted, updated, or deleted.
--
--   Step B — a trigger on invoice itself that recomputes
--             total_amount whenever discount or tax changes,
--             and prevents manual writes to subtotal and
--             total_amount (they are always derived).
--
--   Step C — a CHECK constraint ensuring total_amount cannot
--             be negative (a negative total would indicate a
--             net credit; handle that via a separate credit-note
--             flow, not a negative invoice).
--
-- Formula:
--   subtotal     = SUM(quantity * unit_price) over appointment_service
--   total_amount = subtotal - discount + tax
--
-- Rounding: all intermediate values are kept as NUMERIC(10,2)
-- which is exact; no float arithmetic is used.
-- ============================================================

BEGIN;

-- hedge against negative values
ALTER TABLE invoice
    DROP CONSTRAINT IF EXISTS chk_invoice_total_non_negative;

ALTER TABLE invoice
    ADD CONSTRAINT chk_invoice_total_non_negative
    CHECK (total_amount >= 0);

ALTER TABLE invoice
    DROP CONSTRAINT IF EXISTS chk_invoice_discount_non_negative;

ALTER TABLE invoice
    ADD CONSTRAINT chk_invoice_discount_non_negative
    CHECK (discount >= 0);

ALTER TABLE invoice
    DROP CONSTRAINT IF EXISTS chk_invoice_tax_non_negative;

ALTER TABLE invoice
    ADD CONSTRAINT chk_invoice_tax_non_negative
    CHECK (tax >= 0);

COMMENT ON CONSTRAINT chk_invoice_total_non_negative ON invoice IS
    'BizRule-2: Invoice total equals sum(services) minus discounts plus tax.';

-- 2b. Core recompute function — called by both triggers below.
--     Recalculates subtotal from appointment_service rows, then
--     derives total_amount = subtotal - discount + tax.
--     Uses FOR UPDATE to lock the invoice row against concurrent
--     payment inserts while totals are being recalculated.
CREATE OR REPLACE FUNCTION fn_recompute_invoice_total(p_invoice_id UUID)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_appointment_id UUID;
    v_subtotal       NUMERIC(10,2);
    v_discount       NUMERIC(10,2);
    v_tax            NUMERIC(10,2);
BEGIN
    SELECT appointment_id, discount, tax
      INTO v_appointment_id, v_discount, v_tax
      FROM invoice
     WHERE invoice_id = p_invoice_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'fn_recompute_invoice_total: invoice % does not exist', p_invoice_id;
    END IF;

    SELECT COALESCE(SUM(quantity * unit_price), 0.00)
      INTO v_subtotal
      FROM appointment_service
     WHERE appointment_id = v_appointment_id;

    UPDATE invoice
       SET subtotal     = v_subtotal,
           total_amount = GREATEST(v_subtotal - v_discount + v_tax, 0.00)
     WHERE invoice_id   = p_invoice_id;
END;
$$;

COMMENT ON FUNCTION fn_recompute_invoice_total(UUID) IS
    'BizRule-2: Invoice total equals sum(services) minus discounts plus tax.';

-- 2c. Trigger on appointment_service:
--     Fire after any change to a service line so the parent
--     invoice stays in sync.  We look up the invoice by
--     appointment_id; if no invoice exists yet (still in draft
--     before billing) we skip silently.
CREATE OR REPLACE FUNCTION trg_fn_sync_invoice_on_service_change()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_appt_id   UUID;
    v_inv_id    UUID;
BEGIN
    v_appt_id := COALESCE(NEW.appointment_id, OLD.appointment_id);

    SELECT invoice_id
      INTO v_inv_id
      FROM invoice
     WHERE appointment_id = v_appt_id
     LIMIT 1;

    IF v_inv_id IS NOT NULL THEN
        PERFORM fn_recompute_invoice_total(v_inv_id);
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_invoice_on_service_change ON appointment_service;

CREATE TRIGGER trg_sync_invoice_on_service_change
    AFTER INSERT OR UPDATE OF quantity, unit_price
                 OR DELETE
    ON appointment_service
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_sync_invoice_on_service_change();
COMMENT ON FUNCTION trg_fn_sync_invoice_on_service_change() IS
    'BizRule-2: Fires on appointment_service changes; delegates to fn_recompute_invoice_total to keep invoice totals consistent.';

-- 2d. Trigger on invoice:
--     When discount or tax is edited directly, recompute total_amount.
--     Also block direct writes to subtotal and total_amount from application code (they are always derived).
CREATE OR REPLACE FUNCTION trg_fn_invoice_totals_guard()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    -- Prevent manual overrides of derived columns.
    -- Allow the recompute function itself to write them by checking whether the change came from that function via a session variable.
    IF current_setting('clinic.recomputing_invoice', TRUE) IS DISTINCT FROM 'true' THEN
        IF NEW.subtotal IS DISTINCT FROM OLD.subtotal THEN
            RAISE EXCEPTION
                'BizRule-2: invoice.subtotal is derived from appointment_service rows and cannot be set directly. Modify service lines instead.';
        END IF;
        IF NEW.total_amount IS DISTINCT FROM OLD.total_amount THEN
            RAISE EXCEPTION
                'BizRule-2: invoice.total_amount is computed (subtotal - discount + tax) and cannot be set directly. Adjust discount or tax instead.';
        END IF;
    END IF;

    IF NEW.discount IS DISTINCT FROM OLD.discount
    OR NEW.tax      IS DISTINCT FROM OLD.tax
    THEN
        PERFORM set_config('clinic.recomputing_invoice', 'true', TRUE);
        PERFORM fn_recompute_invoice_total(NEW.invoice_id);
        PERFORM set_config('clinic.recomputing_invoice', 'false', TRUE);

        SELECT subtotal, total_amount
          INTO NEW.subtotal, NEW.total_amount
          FROM invoice
         WHERE invoice_id = NEW.invoice_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_invoice_totals_guard ON invoice;

CREATE TRIGGER trg_invoice_totals_guard
    BEFORE UPDATE OF subtotal, discount, tax, total_amount
    ON invoice
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_invoice_totals_guard();
COMMENT ON FUNCTION trg_fn_invoice_totals_guard() IS
    'BizRule-2: Blocks direct writes to derived invoice columns (subtotal, total_amount) and re-derives total_amount when discount or tax changes.';

COMMIT;


-- ============================================================
-- BizRule-3  PAYMENT CANNOT EXCEED REMAINING BALANCE
-- ============================================================
-- "Remaining balance" = invoice.total_amount - invoice.amount_paid
-- (where amount_paid is the running sum of all posted payments).
--
-- Strategy:
--   Step A — a BEFORE INSERT trigger on payment checks that the
--             new amount does not exceed the balance.  Uses
--             SELECT ... FOR UPDATE on the invoice to prevent
--             two concurrent payments from both passing the
--             check and together exceeding the balance (the
--             classic lost-update / race condition).
--
--   Step B — an AFTER INSERT / UPDATE / DELETE trigger on
--             payment keeps invoice.amount_paid and
--             invoice.status in sync automatically.
--
--   Step C — a CHECK on payment ensures amount > 0 (already
--             present in the original schema; we add a
--             complementary constraint for refunds — a separate
--             payment_method value 'refund' with amount > 0
--             representing money flowing back, recorded as a
--             negative adjustment via the balance sync trigger).
--
-- Refund flow (explicit exception):
--   Refunds are recorded in the payment table with
--   payment_method = 'refund' and a positive amount.  The
--   balance sync trigger subtracts refunds from amount_paid,
--   so the balance increases.  This means overpayment via
--   normal payment_methods is still blocked, but refund rows
--   are always allowed (they reduce, not increase, the paid
--   amount).
-- ============================================================

BEGIN;

-- 3a. Extend payment_method to include 'refund'.
ALTER TABLE payment
    DROP CONSTRAINT IF EXISTS payment_payment_method_check;

ALTER TABLE payment
    ADD CONSTRAINT payment_payment_method_check
    CHECK (payment_method IN ('cash', 'credit_card', 'debit_card', 'check', 'insurance', 'ach', 'other', 'refund'));

-- 3b. BEFORE INSERT guard: prevent overpayment.
CREATE OR REPLACE FUNCTION trg_fn_prevent_overpayment()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_total_amount  NUMERIC(10,2);
    v_amount_paid   NUMERIC(10,2);
    v_remaining     NUMERIC(10,2);
    v_inv_status    VARCHAR(30);
BEGIN
    -- Refunds are always allowed; skip the balance check.
    IF NEW.payment_method = 'refund' THEN
        RETURN NEW;
    END IF;

    -- Lock the invoice row to serialise concurrent payment inserts.
    SELECT total_amount, amount_paid, status
      INTO v_total_amount, v_amount_paid, v_inv_status
      FROM invoice
     WHERE invoice_id = NEW.invoice_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'BizRule-3: Invoice % not found.', NEW.invoice_id;
    END IF;

    IF v_inv_status = 'voided' THEN
        RAISE EXCEPTION
            'BizRule-3: Cannot post a payment against a voided invoice (%).',
            NEW.invoice_id;
    END IF;

    IF v_inv_status = 'paid' THEN
        RAISE EXCEPTION
            'BizRule-3: Invoice % is already fully paid. Use payment_method = ''refund'' to issue a credit.',
            NEW.invoice_id;
    END IF;

    v_remaining := v_total_amount - v_amount_paid;

    IF NEW.amount > v_remaining THEN
        RAISE EXCEPTION
            'BizRule-3: Payment amount (%) exceeds the remaining balance (%) on invoice %. Reduce the payment amount or split across invoices.',
            NEW.amount,
            v_remaining,
            NEW.invoice_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_overpayment ON payment;

CREATE TRIGGER trg_prevent_overpayment
    BEFORE INSERT
    ON payment
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_prevent_overpayment();
COMMENT ON FUNCTION trg_fn_prevent_overpayment() IS
    'BizRule-3: Blocks payment inserts that would exceed the invoice remaining balance. Skips the check for refund payments. Uses SELECT FOR UPDATE to prevent races.';

-- 3c. AFTER INSERT / UPDATE / DELETE on payment:
--     keep invoice.amount_paid and invoice.status consistent.
--     Refund rows reduce amount_paid (the payment_method = refund
--     convention means the clinic is paying the patient back).
CREATE OR REPLACE FUNCTION trg_fn_sync_invoice_amount_paid()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_inv_id        UUID;
    v_amount_paid   NUMERIC(10,2);
    v_total_amount  NUMERIC(10,2);
    v_new_status    VARCHAR(30);
BEGIN
    -- Resolve which invoice was affected.
    v_inv_id := COALESCE(NEW.invoice_id, OLD.invoice_id);

    -- Recompute the authoritative paid total from all payment rows.
    -- Normal payments add to paid; refund rows subtract.
    SELECT COALESCE(SUM(CASE WHEN payment_method = 'refund' THEN -amount ELSE amount END), 0.00)
      INTO v_amount_paid
      FROM payment
     WHERE invoice_id = v_inv_id;

    -- Fetch current total for status derivation (lock for safety).
    SELECT total_amount
      INTO v_total_amount
      FROM invoice
     WHERE invoice_id = v_inv_id
       FOR UPDATE;

    -- Derive status from amounts.
    v_new_status :=
        CASE
            WHEN v_amount_paid <= 0            THEN 'issued'
            WHEN v_amount_paid >= v_total_amount THEN 'paid'
            ELSE                                    'partially_paid'
        END;

    UPDATE invoice
       SET amount_paid = v_amount_paid,
           status      = v_new_status
     WHERE invoice_id  = v_inv_id
       AND status NOT IN ('voided', 'collections');

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_invoice_amount_paid ON payment;

CREATE TRIGGER trg_sync_invoice_amount_paid
    AFTER INSERT OR UPDATE OR DELETE
    ON payment
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_sync_invoice_amount_paid();
COMMENT ON FUNCTION trg_fn_sync_invoice_amount_paid() IS
    'BizRule-3: Keeps invoice.amount_paid and invoice.status in sync after any payment INSERT, UPDATE, or DELETE. Refund rows reduce amount_paid.';

COMMIT;
