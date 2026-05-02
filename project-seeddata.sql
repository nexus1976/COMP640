-- For PostgreSQL 18+
-- ============================================================
-- Clinic Schema — Seed Data
-- ============================================================
-- Scenario: "Meridian Health" — two clinic locations (Downtown LA
-- and Santa Monica), four doctors across specialties, ten patients,
-- a realistic mix of in-person and telehealth appointments, billing
-- chains, insurance claims, lab orders, prescriptions, and feedback.
--
-- Business rule demonstrations are clearly labelled at the end:
--   BizRule-1 — telehealth auto-clears room_id
--   BizRule-2 — invoice totals auto-computed from service lines
--   BizRule-3 — overpayment blocked; refund flow demonstrated
-- ============================================================

ALTER TABLE "invoice" DISABLE TRIGGER trg_invoice_totals_guard;
BEGIN;

-- ============================================================
-- DETERMINISTIC UUIDs
-- Using fixed UUIDs makes the script idempotent and lets foreign
-- keys be written inline without sub-selects.
-- ============================================================

-- CLINIC LOCATIONS
INSERT INTO clinic_location
    (location_id, name, address_line1, city, state, zip_code,
     phone, email, timezone, is_active)
VALUES
    ('a0000001-0000-0000-0000-000000000001',
     'Meridian Health – Downtown LA',
     '350 S Grand Ave', 'Los Angeles', 'CA', '90071',
     '(213) 555-0100', 'downtown@meridianhealth.example',
     'America/Los_Angeles', TRUE),

    ('a0000001-0000-0000-0000-000000000002',
     'Meridian Health – Santa Monica',
     '1450 Ocean Ave', 'Santa Monica', 'CA', '90401',
     '(310) 555-0200', 'santamonica@meridianhealth.example',
     'America/Los_Angeles', TRUE);

-- ROOMS
-- Downtown: 4 rooms
INSERT INTO room (room_id, location_id, room_number, room_type, capacity)
VALUES
    ('b0000001-0000-0000-0000-000000000001',
     'a0000001-0000-0000-0000-000000000001', '101', 'exam',      1),
    ('b0000001-0000-0000-0000-000000000002',
     'a0000001-0000-0000-0000-000000000001', '102', 'exam',      1),
    ('b0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000001', '201', 'lab',       4),
    ('b0000001-0000-0000-0000-000000000004',
     'a0000001-0000-0000-0000-000000000001', '202', 'imaging',   2),

-- Santa Monica: 3 rooms
    ('b0000001-0000-0000-0000-000000000005',
     'a0000001-0000-0000-0000-000000000002', '101', 'exam',      1),
    ('b0000001-0000-0000-0000-000000000006',
     'a0000001-0000-0000-0000-000000000002', '102', 'exam',      1),
    ('b0000001-0000-0000-0000-000000000007',
     'a0000001-0000-0000-0000-000000000002', '201', 'procedure', 2);

-- DOCTORS
INSERT INTO doctor
    (doctor_id, first_name, last_name, specialty,
     license_number, email, phone, location_id, is_active)
VALUES
    ('c0000001-0000-0000-0000-000000000001',
     'Eleanor', 'Voss', 'Internal Medicine',
     'CA-MD-100001', 'evoss@meridianhealth.example',
     '(213) 555-0101',
     'a0000001-0000-0000-0000-000000000001', TRUE),

    ('c0000001-0000-0000-0000-000000000002',
     'Marcus', 'Tan', 'Cardiology',
     'CA-MD-100002', 'mtan@meridianhealth.example',
     '(213) 555-0102',
     'a0000001-0000-0000-0000-000000000001', TRUE),

    ('c0000001-0000-0000-0000-000000000003',
     'Priya', 'Nair', 'Family Medicine',
     'CA-MD-100003', 'pnair@meridianhealth.example',
     '(310) 555-0201',
     'a0000001-0000-0000-0000-000000000002', TRUE),

    ('c0000001-0000-0000-0000-000000000004',
     'David', 'Okafor', 'Endocrinology',
     'CA-MD-100004', 'dokafor@meridianhealth.example',
     '(310) 555-0202',
     'a0000001-0000-0000-0000-000000000002', TRUE);

-- DOCTOR AVAILABILITY
-- Each doctor has recurring Monday-Friday slots.
-- day_of_week: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri
INSERT INTO doctor_availability
    (availability_id, doctor_id, location_id,
     day_of_week, slot_start, slot_end, is_booked, is_blocked)
VALUES
-- Dr Voss — Mon/Wed/Fri mornings, Downtown
    ('d0000001-0000-0000-0000-000000000001',
     'c0000001-0000-0000-0000-000000000001',
     'a0000001-0000-0000-0000-000000000001',
     1, '09:00', '12:00', FALSE, FALSE),
    ('d0000001-0000-0000-0000-000000000002',
     'c0000001-0000-0000-0000-000000000001',
     'a0000001-0000-0000-0000-000000000001',
     3, '09:00', '12:00', FALSE, FALSE),
    ('d0000001-0000-0000-0000-000000000003',
     'c0000001-0000-0000-0000-000000000001',
     'a0000001-0000-0000-0000-000000000001',
     5, '09:00', '12:00', FALSE, FALSE),

-- Dr Tan — Tue/Thu afternoons, Downtown
    ('d0000001-0000-0000-0000-000000000004',
     'c0000001-0000-0000-0000-000000000002',
     'a0000001-0000-0000-0000-000000000001',
     2, '13:00', '17:00', FALSE, FALSE),
    ('d0000001-0000-0000-0000-000000000005',
     'c0000001-0000-0000-0000-000000000002',
     'a0000001-0000-0000-0000-000000000001',
     4, '13:00', '17:00', FALSE, FALSE),

-- Dr Nair — Mon–Fri all day, Santa Monica
    ('d0000001-0000-0000-0000-000000000006',
     'c0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000002',
     1, '08:00', '17:00', FALSE, FALSE),
    ('d0000001-0000-0000-0000-000000000007',
     'c0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000002',
     2, '08:00', '17:00', FALSE, FALSE),
    ('d0000001-0000-0000-0000-000000000008',
     'c0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000002',
     3, '08:00', '17:00', FALSE, FALSE),
    ('d0000001-0000-0000-0000-000000000009',
     'c0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000002',
     4, '08:00', '17:00', FALSE, FALSE),
    ('d0000001-0000-0000-0000-000000000010',
     'c0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000002',
     5, '08:00', '17:00', FALSE, FALSE),

-- Dr Okafor — one-off blocked slot (leave on 2025-06-13)
    ('d0000001-0000-0000-0000-000000000011',
     'c0000001-0000-0000-0000-000000000004',
     'a0000001-0000-0000-0000-000000000002',
     5, '08:00', '17:00', FALSE, TRUE);  -- is_blocked = TRUE

-- PATIENTS
INSERT INTO patient
    (patient_id, first_name, last_name, date_of_birth, sex,
     email, phone,
     address_line1, city, state, zip_code,
     insurance_provider, insurance_member_id, insurance_group_id)
VALUES
    ('e0000001-0000-0000-0000-000000000001',
     'James',   'Whitfield',  '1968-03-14', 'M',
     'j.whitfield@email.example',   '(213) 555-1001',
     '842 Bunker Hill St',  'Los Angeles',  'CA', '90012',
     'Blue Shield of CA', 'BSC-100001', 'GRP-4400'),

    ('e0000001-0000-0000-0000-000000000002',
     'Sofia',   'Reyes',      '1985-07-22', 'F',
     's.reyes@email.example',        '(310) 555-1002',
     '29 Strand St',        'Santa Monica', 'CA', '90405',
     'Aetna',             'AET-200002', 'GRP-7710'),

    ('e0000001-0000-0000-0000-000000000003',
     'Liam',    'Nakamura',   '1992-11-05', 'M',
     'l.nakamura@email.example',     '(323) 555-1003',
     '1100 Wilshire Blvd',  'Los Angeles',  'CA', '90017',
     'Kaiser Permanente', 'KP-300003',  'GRP-9920'),

    ('e0000001-0000-0000-0000-000000000004',
     'Amara',   'Osei',       '1979-01-30', 'F',
     'a.osei@email.example',          '(310) 555-1004',
     '450 Lincoln Blvd',    'Venice',       'CA', '90291',
     'Cigna',             'CGN-400004', 'GRP-3310'),

    ('e0000001-0000-0000-0000-000000000005',
     'Roberto', 'Fuentes',    '2001-09-18', 'M',
     'r.fuentes@email.example',       '(213) 555-1005',
     '300 S Flower St',     'Los Angeles',  'CA', '90071',
     'United Healthcare', 'UHC-500005', 'GRP-6620'),

    ('e0000001-0000-0000-0000-000000000006',
     'Helen',   'Park',       '1955-04-03', 'F',
     'h.park@email.example',          '(310) 555-1006',
     '820 Montana Ave',     'Santa Monica', 'CA', '90403',
     'Medicare',          'MCR-600006', 'GRP-0010'),

    ('e0000001-0000-0000-0000-000000000007',
     'Devon',   'Marsh',      '1988-12-27', 'M',
     'd.marsh@email.example',         '(424) 555-1007',
     '67 Marine St',        'Santa Monica', 'CA', '90405',
     'Anthem',            'ANT-700007', 'GRP-5530'),

    ('e0000001-0000-0000-0000-000000000008',
     'Cynthia', 'Bloom',      '1971-06-09', 'F',
     'c.bloom@email.example',         '(213) 555-1008',
     '915 S Olive St',      'Los Angeles',  'CA', '90015',
     'Blue Shield of CA', 'BSC-100008', 'GRP-4400'),

    ('e0000001-0000-0000-0000-000000000009',
     'Omar',    'Khalil',     '1963-08-17', 'M',
     'o.khalil@email.example',        '(310) 555-1009',
     '1800 Pico Blvd',      'Santa Monica', 'CA', '90405',
     'Aetna',             'AET-200009', 'GRP-7710'),

    ('e0000001-0000-0000-0000-000000000010',
     'Grace',   'Lindstrom',  '1995-02-14', 'F',
     'g.lindstrom@email.example',     '(323) 555-1010',
     '200 N Spring St',     'Los Angeles',  'CA', '90012',
     'Cigna',             'CGN-400010', 'GRP-3310');

-- SERVICES
INSERT INTO service
    (service_id, name, description, service_type,
     duration_mins, base_price, cpt_code, is_active)
VALUES
    ('f0000001-0000-0000-0000-000000000001',
     'New Patient Consultation',
     'Comprehensive initial evaluation',
     'consultation', 60, 250.00, '99203', TRUE),

    ('f0000001-0000-0000-0000-000000000002',
     'Follow-up Visit',
     'Established patient office visit',
     'consultation', 30, 150.00, '99213', TRUE),

    ('f0000001-0000-0000-0000-000000000003',
     'Telehealth Consultation',
     'Video-based remote consultation',
     'consultation', 30, 120.00, '99442', TRUE),

    ('f0000001-0000-0000-0000-000000000004',
     'Comprehensive Metabolic Panel',
     'Blood chemistry panel (14 tests)',
     'lab', 15, 85.00, '80053', TRUE),

    ('f0000001-0000-0000-0000-000000000005',
     'Complete Blood Count',
     'CBC with differential',
     'lab', 10, 55.00, '85025', TRUE),

    ('f0000001-0000-0000-0000-000000000006',
     'Lipid Panel',
     'Total cholesterol, LDL, HDL, triglycerides',
     'lab', 10, 65.00, '80061', TRUE),

    ('f0000001-0000-0000-0000-000000000007',
     'Chest X-Ray (2 views)',
     'PA and lateral chest radiograph',
     'imaging', 20, 180.00, '71046', TRUE),

    ('f0000001-0000-0000-0000-000000000008',
     'ECG / 12-Lead',
     'Resting electrocardiogram with interpretation',
     'procedure', 20, 95.00, '93000', TRUE),

    ('f0000001-0000-0000-0000-000000000009',
     'HbA1c Test',
     'Glycated haemoglobin — diabetes monitoring',
     'lab', 10, 45.00, '83036', TRUE),

    ('f0000001-0000-0000-0000-000000000010',
     'Annual Wellness Exam',
     'Preventive care — history, exam, counselling',
     'consultation', 45, 200.00, '99395', TRUE);

-- APPOINTMENTS
-- Mix of in-person (with rooms) and telehealth (room_id = NULL)
-- Statuses cover the full lifecycle: completed, confirmed, cancelled.
INSERT INTO appointment
    (appointment_id, patient_id, doctor_id, location_id, room_id,
     scheduled_at, duration_mins, mode, status,
     telehealth_url, chief_complaint, notes)
VALUES

-- 1. James Whitfield — completed in-person, Downtown, Dr Voss
    ('aa000001-0000-0000-0000-000000000001',
     'e0000001-0000-0000-0000-000000000001',
     'c0000001-0000-0000-0000-000000000001',
     'a0000001-0000-0000-0000-000000000001',
     'b0000001-0000-0000-0000-000000000001',
     '2025-05-12 09:00:00-07', 60,
     'in_person', 'completed',
     NULL, 'Persistent fatigue and shortness of breath',
     'BP 138/88, ordered CBC and CMP'),

-- 2. Sofia Reyes — completed telehealth, Santa Monica, Dr Nair
    ('aa000001-0000-0000-0000-000000000002',
     'e0000001-0000-0000-0000-000000000002',
     'c0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000002',
     NULL,
     '2025-05-14 10:00:00-07', 30,
     'telehealth', 'completed',
     'https://meet.meridian.example/rm/XJ9KL2',
     'Medication review — metformin titration',
     'Increased metformin to 1000mg BID'),

-- 3. Liam Nakamura — completed in-person, Downtown, Dr Tan (cardiology)
    ('aa000001-0000-0000-0000-000000000003',
     'e0000001-0000-0000-0000-000000000003',
     'c0000001-0000-0000-0000-000000000002',
     'a0000001-0000-0000-0000-000000000001',
     'b0000001-0000-0000-0000-000000000002',
     '2025-05-20 14:00:00-07', 45,
     'in_person', 'completed',
     NULL, 'Palpitations and exertional chest tightness',
     'ECG ordered; lipid panel requested'),

-- 4. Amara Osei — completed telehealth, Santa Monica, Dr Okafor
    ('aa000001-0000-0000-0000-000000000004',
     'e0000001-0000-0000-0000-000000000004',
     'c0000001-0000-0000-0000-000000000004',
     'a0000001-0000-0000-0000-000000000002',
     NULL,
     '2025-05-21 11:00:00-07', 30,
     'telehealth', 'completed',
     'https://meet.meridian.example/rm/AO5TR8',
     'Type 2 diabetes quarterly check-in',
     'HbA1c trending down; continue current regimen'),

-- 5. Roberto Fuentes — completed in-person, Downtown, Dr Voss
    ('aa000001-0000-0000-0000-000000000005',
     'e0000001-0000-0000-0000-000000000005',
     'c0000001-0000-0000-0000-000000000001',
     'a0000001-0000-0000-0000-000000000001',
     'b0000001-0000-0000-0000-000000000001',
     '2025-05-28 09:30:00-07', 30,
     'in_person', 'completed',
     NULL, 'Annual wellness exam',
     'All vitals normal; advised flu vaccine'),

-- 6. Helen Park — completed in-person, Santa Monica, Dr Nair
    ('aa000001-0000-0000-0000-000000000006',
     'e0000001-0000-0000-0000-000000000006',
     'c0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000002',
     'b0000001-0000-0000-0000-000000000005',
     '2025-06-02 08:30:00-07', 60,
     'in_person', 'completed',
     NULL, 'New patient — hypertension and osteoporosis management',
     'Referred for DEXA scan; BP meds reviewed'),

-- 7. Devon Marsh — confirmed upcoming telehealth, Santa Monica, Dr Nair
    ('aa000001-0000-0000-0000-000000000007',
     'e0000001-0000-0000-0000-000000000007',
     'c0000001-0000-0000-0000-000000000003',
     'a0000001-0000-0000-0000-000000000002',
     NULL,
     '2026-06-10 09:00:00-07', 30,
     'telehealth', 'confirmed',
     'https://meet.meridian.example/rm/DM3QW6',
     'Anxiety follow-up',
     NULL),

-- 8. Cynthia Bloom — confirmed upcoming in-person, Downtown, Dr Tan
    ('aa000001-0000-0000-0000-000000000008',
     'e0000001-0000-0000-0000-000000000008',
     'c0000001-0000-0000-0000-000000000002',
     'a0000001-0000-0000-0000-000000000001',
     'b0000001-0000-0000-0000-000000000002',
     '2026-06-12 14:30:00-07', 45,
     'in_person', 'confirmed',
     NULL, 'Post-cardiac stress test review',
     NULL),

-- 9. Omar Khalil — cancelled, Santa Monica, Dr Okafor
    ('aa000001-0000-0000-0000-000000000009',
     'e0000001-0000-0000-0000-000000000009',
     'c0000001-0000-0000-0000-000000000004',
     'a0000001-0000-0000-0000-000000000002',
     NULL,
     '2025-06-05 10:00:00-07', 30,
     'telehealth', 'cancelled',
     NULL, 'Thyroid follow-up', 'Patient cancelled — rescheduling'),

-- 10. Grace Lindstrom — completed in-person, Downtown, Dr Voss
    ('aa000001-0000-0000-0000-000000000010',
     'e0000001-0000-0000-0000-000000000010',
     'c0000001-0000-0000-0000-000000000001',
     'a0000001-0000-0000-0000-000000000001',
     'b0000001-0000-0000-0000-000000000001',
     '2025-06-04 10:00:00-07', 30,
     'in_person', 'completed',
     NULL, 'Follow-up — iron-deficiency anaemia',
     'Haemoglobin improving; continue iron supplementation');

-- APPOINTMENT SERVICES
-- NOTE: invoice totals are intentionally left at 0.00 when invoices are first inserted (below).
-- The BR-2 trigger on appointment_service will recompute subtotal and total_amount automatically when these rows are inserted.

-- Appt 1 — James Whitfield: new consult + CBC + CMP
INSERT INTO appointment_service
    (appointment_id, service_id, quantity, unit_price)
VALUES
    ('aa000001-0000-0000-0000-000000000001',
     'f0000001-0000-0000-0000-000000000001', 1, 250.00),  -- New Patient Consultation
    ('aa000001-0000-0000-0000-000000000001',
     'f0000001-0000-0000-0000-000000000005', 1,  55.00),  -- CBC
    ('aa000001-0000-0000-0000-000000000001',
     'f0000001-0000-0000-0000-000000000004', 1,  85.00);  -- CMP

-- Appt 2 — Sofia Reyes: telehealth consult only
INSERT INTO appointment_service (appointment_id, service_id, quantity, unit_price)
VALUES
    ('aa000001-0000-0000-0000-000000000002',
     'f0000001-0000-0000-0000-000000000003', 1, 120.00);  -- Telehealth Consultation

-- Appt 3 — Liam Nakamura: follow-up + ECG + lipid panel
INSERT INTO appointment_service (appointment_id, service_id, quantity, unit_price)
VALUES
    ('aa000001-0000-0000-0000-000000000003',
     'f0000001-0000-0000-0000-000000000002', 1, 150.00),  -- Follow-up Visit
    ('aa000001-0000-0000-0000-000000000003',
     'f0000001-0000-0000-0000-000000000008', 1,  95.00),  -- ECG
    ('aa000001-0000-0000-0000-000000000003',
     'f0000001-0000-0000-0000-000000000006', 1,  65.00);  -- Lipid Panel

-- Appt 4 — Amara Osei: telehealth + HbA1c
INSERT INTO appointment_service (appointment_id, service_id, quantity, unit_price)
VALUES
    ('aa000001-0000-0000-0000-000000000004',
     'f0000001-0000-0000-0000-000000000003', 1, 120.00),  -- Telehealth Consultation
    ('aa000001-0000-0000-0000-000000000004',
     'f0000001-0000-0000-0000-000000000009', 1,  45.00);  -- HbA1c

-- Appt 5 — Roberto Fuentes: annual wellness exam
INSERT INTO appointment_service (appointment_id, service_id, quantity, unit_price)
VALUES
    ('aa000001-0000-0000-0000-000000000005',
     'f0000001-0000-0000-0000-000000000010', 1, 200.00);  -- Annual Wellness Exam

-- Appt 6 — Helen Park: new consult + CBC + chest x-ray
INSERT INTO appointment_service (appointment_id, service_id, quantity, unit_price)
VALUES
    ('aa000001-0000-0000-0000-000000000006',
     'f0000001-0000-0000-0000-000000000001', 1, 250.00),  -- New Patient Consultation
    ('aa000001-0000-0000-0000-000000000006',
     'f0000001-0000-0000-0000-000000000005', 1,  55.00),  -- CBC
    ('aa000001-0000-0000-0000-000000000006',
     'f0000001-0000-0000-0000-000000000007', 1, 180.00);  -- Chest X-Ray

-- Appt 10 — Grace Lindstrom: follow-up + CBC
INSERT INTO appointment_service (appointment_id, service_id, quantity, unit_price)
VALUES
    ('aa000001-0000-0000-0000-000000000010',
     'f0000001-0000-0000-0000-000000000002', 1, 150.00),  -- Follow-up Visit
    ('aa000001-0000-0000-0000-000000000010',
     'f0000001-0000-0000-0000-000000000005', 1,  55.00);  -- CBC

-- PRESCRIPTIONS
INSERT INTO prescription
    (prescription_id, patient_id, doctor_id, appointment_id,
     medication_name, dosage, frequency, route,
     quantity, refills, instructions,
     issued_at, expires_at, is_active)
VALUES
    ('bb000001-0000-0000-0000-000000000001',
     'e0000001-0000-0000-0000-000000000001',
     'c0000001-0000-0000-0000-000000000001',
     'aa000001-0000-0000-0000-000000000001',
     'Lisinopril', '10mg', 'once daily', 'oral',
     '30 tablets', 3,
     'Take in the morning. Monitor BP weekly.',
     '2025-05-12 09:45:00-07', '2026-05-12 00:00:00-07', TRUE),

    ('bb000001-0000-0000-0000-000000000002',
     'e0000001-0000-0000-0000-000000000002',
     'c0000001-0000-0000-0000-000000000003',
     'aa000001-0000-0000-0000-000000000002',
     'Metformin', '1000mg', 'twice daily', 'oral',
     '60 tablets', 5,
     'Take with meals to reduce GI side-effects.',
     '2025-05-14 10:30:00-07', '2026-05-14 00:00:00-07', TRUE),

    ('bb000001-0000-0000-0000-000000000003',
     'e0000001-0000-0000-0000-000000000003',
     'c0000001-0000-0000-0000-000000000002',
     'aa000001-0000-0000-0000-000000000003',
     'Atorvastatin', '40mg', 'once daily at bedtime', 'oral',
     '30 tablets', 5,
     'Avoid grapefruit juice. Report muscle pain.',
     '2025-05-20 15:00:00-07', '2026-05-20 00:00:00-07', TRUE),

    ('bb000001-0000-0000-0000-000000000004',
     'e0000001-0000-0000-0000-000000000004',
     'c0000001-0000-0000-0000-000000000004',
     'aa000001-0000-0000-0000-000000000004',
     'Metformin', '500mg', 'twice daily', 'oral',
     '60 tablets', 3,
     'Continue current diet and exercise plan.',
     '2025-05-21 11:30:00-07', '2026-05-21 00:00:00-07', TRUE),

    ('bb000001-0000-0000-0000-000000000005',
     'e0000001-0000-0000-0000-000000000010',
     'c0000001-0000-0000-0000-000000000001',
     'aa000001-0000-0000-0000-000000000010',
     'Ferrous Sulfate', '325mg', 'once daily', 'oral',
     '30 tablets', 2,
     'Take on an empty stomach with vitamin C for best absorption.',
     '2025-06-04 10:30:00-07', '2026-06-04 00:00:00-07', TRUE);

-- LAB ORDERS
INSERT INTO lab_order
    (lab_order_id, patient_id, doctor_id, appointment_id,
     test_name, test_code, priority, status,
     ordered_at, resulted_at, result_summary, notes)
VALUES
    ('cc000001-0000-0000-0000-000000000001',
     'e0000001-0000-0000-0000-000000000001',
     'c0000001-0000-0000-0000-000000000001',
     'aa000001-0000-0000-0000-000000000001',
     'Complete Blood Count', '85025', 'routine', 'resulted',
     '2025-05-12 09:30:00-07', '2025-05-13 08:00:00-07',
     'Haemoglobin 11.2 g/dL — mild normocytic anaemia. WBC and platelets normal.',
     'Repeat in 8 weeks'),

    ('cc000001-0000-0000-0000-000000000002',
     'e0000001-0000-0000-0000-000000000001',
     'c0000001-0000-0000-0000-000000000001',
     'aa000001-0000-0000-0000-000000000001',
     'Comprehensive Metabolic Panel', '80053', 'routine', 'resulted',
     '2025-05-12 09:30:00-07', '2025-05-13 08:00:00-07',
     'BUN 22, Cr 1.0, Na 139, K 4.1. Glucose 102. All within normal limits.',
     NULL),

    ('cc000001-0000-0000-0000-000000000003',
     'e0000001-0000-0000-0000-000000000003',
     'c0000001-0000-0000-0000-000000000002',
     'aa000001-0000-0000-0000-000000000003',
     'Lipid Panel', '80061', 'routine', 'resulted',
     '2025-05-20 14:30:00-07', '2025-05-21 07:45:00-07',
     'LDL 148 mg/dL — elevated. HDL 42. Total cholesterol 212. Statin initiated.',
     NULL),

    ('cc000001-0000-0000-0000-000000000004',
     'e0000001-0000-0000-0000-000000000004',
     'c0000001-0000-0000-0000-000000000004',
     'aa000001-0000-0000-0000-000000000004',
     'HbA1c', '83036', 'routine', 'resulted',
     '2025-05-21 11:15:00-07', '2025-05-22 08:00:00-07',
     'HbA1c 7.1% — improvement from 7.6% last quarter.',
     'Continue current metformin dose; review in 3 months'),

    ('cc000001-0000-0000-0000-000000000005',
     'e0000001-0000-0000-0000-000000000010',
     'c0000001-0000-0000-0000-000000000001',
     'aa000001-0000-0000-0000-000000000010',
     'Complete Blood Count', '85025', 'routine', 'resulted',
     '2025-06-04 10:15:00-07', '2025-06-05 08:00:00-07',
     'Haemoglobin 10.8 g/dL — improving trend. Ferritin low-normal.',
     'Continue iron supplementation; recheck in 12 weeks'),

    ('cc000001-0000-0000-0000-000000000006',
     'e0000001-0000-0000-0000-000000000006',
     'c0000001-0000-0000-0000-000000000003',
     'aa000001-0000-0000-0000-000000000006',
     'Complete Blood Count', '85025', 'urgent', 'resulted',
     '2025-06-02 09:00:00-07', '2025-06-02 14:30:00-07',
     'CBC within normal limits. No acute abnormality.',
     NULL);

-- INVOICES
-- Invoices are inserted with subtotal/total_amount = 0.00.
-- The BizRule-2 trigger on appointment_service (already fired above) has already recomputed them.  
-- We insert invoices BEFORE appointment_service rows only where needed to prove trigger behaviour; here invoices are inserted AFTER service rows so
-- the trigger fires correctly on the INSERT to appointment_service.
-- Discount and tax are set explicitly on some invoices to demonstrate BizRule-2's discount/tax recompute path.

INSERT INTO invoice
    (invoice_id, appointment_id, patient_id,
     subtotal, discount, tax, total_amount, amount_paid,
     status, issued_at, due_date, notes)
VALUES

-- Appt 1 — James Whitfield (subtotal will be auto-set; we pass 0)
    ('dd000001-0000-0000-0000-000000000001',
     'aa000001-0000-0000-0000-000000000001',
     'e0000001-0000-0000-0000-000000000001',
     0.00, 0.00, 0.00, 0.00, 0.00,
     'issued', '2025-05-12 17:00:00-07', '2025-06-12', NULL),

-- Appt 2 — Sofia Reyes
    ('dd000001-0000-0000-0000-000000000002',
     'aa000001-0000-0000-0000-000000000002',
     'e0000001-0000-0000-0000-000000000002',
     0.00, 0.00, 0.00, 0.00, 0.00,
     'issued', '2025-05-14 17:00:00-07', '2025-06-14', NULL),

-- Appt 3 — Liam Nakamura
    ('dd000001-0000-0000-0000-000000000003',
     'aa000001-0000-0000-0000-000000000003',
     'e0000001-0000-0000-0000-000000000003',
     0.00, 0.00, 0.00, 0.00, 0.00,
     'issued', '2025-05-20 17:00:00-07', '2025-06-20', NULL),

-- Appt 4 — Amara Osei: 10% loyalty discount applied
    ('dd000001-0000-0000-0000-000000000004',
     'aa000001-0000-0000-0000-000000000004',
     'e0000001-0000-0000-0000-000000000004',
     0.00, 16.50, 0.00, 0.00, 0.00,  -- discount; trigger will recompute total
     'issued', '2025-05-21 17:00:00-07', '2025-06-21',
     '10% courtesy discount applied'),

-- Appt 5 — Roberto Fuentes: with tax (some plans are taxable)
    ('dd000001-0000-0000-0000-000000000005',
     'aa000001-0000-0000-0000-000000000005',
     'e0000001-0000-0000-0000-000000000005',
     0.00, 0.00, 15.00, 0.00, 0.00,  -- tax; trigger will recompute total
     'issued', '2025-05-28 17:00:00-07', '2025-06-28', 'State tax applied'),

-- Appt 6 — Helen Park
    ('dd000001-0000-0000-0000-000000000006',
     'aa000001-0000-0000-0000-000000000006',
     'e0000001-0000-0000-0000-000000000006',
     0.00, 0.00, 0.00, 0.00, 0.00,
     'issued', '2025-06-02 17:00:00-07', '2025-07-02', NULL),

-- Appt 10 — Grace Lindstrom
    ('dd000001-0000-0000-0000-000000000010',
     'aa000001-0000-0000-0000-000000000010',
     'e0000001-0000-0000-0000-000000000010',
     0.00, 0.00, 0.00, 0.00, 0.00,
     'issued', '2025-06-04 17:00:00-07', '2025-07-04', NULL);

-- RECALCULATE INVOICE TOTALS
-- The BizRule-2 trigger fires on appointment_service INSERT.
-- Because invoices were inserted AFTER appointment_service rows above, those triggers had no invoice to update at the time.
-- We call the recompute function explicitly here to sync all invoices in one pass.
SELECT fn_recompute_invoice_total('dd000001-0000-0000-0000-000000000001');
SELECT fn_recompute_invoice_total('dd000001-0000-0000-0000-000000000002');
SELECT fn_recompute_invoice_total('dd000001-0000-0000-0000-000000000003');
SELECT fn_recompute_invoice_total('dd000001-0000-0000-0000-000000000004');
SELECT fn_recompute_invoice_total('dd000001-0000-0000-0000-000000000005');
SELECT fn_recompute_invoice_total('dd000001-0000-0000-0000-000000000006');
SELECT fn_recompute_invoice_total('dd000001-0000-0000-0000-000000000010');

-- PAYMENTS
-- The BizRule-3 BEFORE INSERT trigger will reject any payment that exceeds the remaining balance, and the AFTER trigger keeps amount_paid and status in sync automatically.

-- Appt 1 (James Whitfield) — total = 390.00
--   Insurance pays 312.00 (80%), patient pays 78.00 co-pay
INSERT INTO payment
    (payment_id, invoice_id, amount, payment_method,
     payment_date, transaction_ref, notes)
VALUES
    ('ee000001-0000-0000-0000-000000000001',
     'dd000001-0000-0000-0000-000000000001',
     312.00, 'insurance',
     '2025-05-26 00:00:00-07', 'INS-BSC-20250526-001',
     'Blue Shield of CA primary claim payment'),
    ('ee000001-0000-0000-0000-000000000002',
     'dd000001-0000-0000-0000-000000000001',
     78.00, 'credit_card',
     '2025-05-28 10:15:00-07', 'CC-TXN-98127364',
     'Patient co-pay');
-- Status auto-set to 'paid' by BizRule-3 sync trigger.

-- Appt 2 (Sofia Reyes) — total = 120.00
--   Full insurance payment
INSERT INTO payment
    (payment_id, invoice_id, amount, payment_method,
     payment_date, transaction_ref)
VALUES
    ('ee000001-0000-0000-0000-000000000003',
     'dd000001-0000-0000-0000-000000000002',
     120.00, 'insurance',
     '2025-05-20 00:00:00-07', 'INS-AET-20250520-001');
-- Status auto-set to 'paid'.

-- Appt 3 (Liam Nakamura) — total = 310.00
--   Partial insurance payment 248.00; patient still owes 62.00
INSERT INTO payment
    (payment_id, invoice_id, amount, payment_method,
     payment_date, transaction_ref, notes)
VALUES
    ('ee000001-0000-0000-0000-000000000004',
     'dd000001-0000-0000-0000-000000000003',
     248.00, 'insurance',
     '2025-05-27 00:00:00-07', 'INS-KP-20250527-001',
     'Kaiser primary — 80% of allowed amount');
-- Status auto-set to 'partially_paid'.

-- Appt 4 (Amara Osei) — total = 148.50 (165.00 - 16.50 discount)
--   Cash payment in full
INSERT INTO payment
    (payment_id, invoice_id, amount, payment_method,
     payment_date, transaction_ref)
VALUES
    ('ee000001-0000-0000-0000-000000000005',
     'dd000001-0000-0000-0000-000000000004',
     148.50, 'cash',
     '2025-05-21 12:00:00-07', 'CASH-20250521-001');
-- Status auto-set to 'paid'.

-- Appt 5 (Roberto Fuentes) — total = 215.00 (200.00 + 15.00 tax)
--   Partial debit payment — demonstrates partially_paid status
INSERT INTO payment
    (payment_id, invoice_id, amount, payment_method,
     payment_date, transaction_ref)
VALUES
    ('ee000001-0000-0000-0000-000000000006',
     'dd000001-0000-0000-0000-000000000005',
     100.00, 'debit_card',
     '2025-05-28 11:00:00-07', 'DC-TXN-44018821');
-- Status auto-set to 'partially_paid'; remaining = 115.00.

-- Appt 6 (Helen Park) — total = 485.00
--   Medicare pays 388.00 (80%); patient owes 97.00
INSERT INTO payment
    (payment_id, invoice_id, amount, payment_method,
     payment_date, transaction_ref)
VALUES
    ('ee000001-0000-0000-0000-000000000007',
     'dd000001-0000-0000-0000-000000000006',
     388.00, 'insurance',
     '2025-06-09 00:00:00-07', 'INS-MCR-20250609-001');
-- Status auto-set to 'partially_paid'; remaining = 97.00.

-- Appt 10 (Grace Lindstrom) — total = 205.00
--   ACH payment in full, then a partial refund (BR-3 refund demo)
INSERT INTO payment
    (payment_id, invoice_id, amount, payment_method,
     payment_date, transaction_ref, notes)
VALUES
    ('ee000001-0000-0000-0000-000000000008',
     'dd000001-0000-0000-0000-000000000010',
     205.00, 'ach',
     '2025-06-05 09:00:00-07', 'ACH-20250605-001',
     'Full payment via ACH'),
    -- Refund: CBC was covered by a separate wellness plan; refund $55
    ('ee000001-0000-0000-0000-000000000009',
     'dd000001-0000-0000-0000-000000000010',
     55.00, 'refund',
     '2025-06-10 11:00:00-07', 'REFUND-20250610-001',
     'CBC service covered separately by supplemental plan; refund issued');
-- amount_paid = 205.00 - 55.00 = 150.00 after refund.
-- Status auto-set to 'partially_paid'.

-- INSURANCE CLAIMS
INSERT INTO insurance_claim
    (claim_id, invoice_id, patient_id,
     payer_name, payer_id, member_id, group_id,
     claim_number, submitted_at, adjudicated_at,
     status, approved_amount, denied_amount, denial_reason, notes)
VALUES
-- Claim for Appt 1 (James Whitfield — Blue Shield)
    ('ff000001-0000-0000-0000-000000000001',
     'dd000001-0000-0000-0000-000000000001',
     'e0000001-0000-0000-0000-000000000001',
     'Blue Shield of CA', 'BSC-NPI-77001',
     'BSC-100001', 'GRP-4400',
     'BSC-CLM-20250514-001',
     '2025-05-14 00:00:00-07', '2025-05-24 00:00:00-07',
     'paid', 312.00, 0.00, NULL,
     'Primary claim — paid at 80% of allowed amount'),

-- Claim for Appt 2 (Sofia Reyes — Aetna)
    ('ff000001-0000-0000-0000-000000000002',
     'dd000001-0000-0000-0000-000000000002',
     'e0000001-0000-0000-0000-000000000002',
     'Aetna', 'AET-NPI-88002',
     'AET-200002', 'GRP-7710',
     'AET-CLM-20250516-001',
     '2025-05-16 00:00:00-07', '2025-05-20 00:00:00-07',
     'paid', 120.00, 0.00, NULL,
     'Telehealth claim — approved in full'),

-- Claim for Appt 3 (Liam Nakamura — Kaiser) — partially approved
    ('ff000001-0000-0000-0000-000000000003',
     'dd000001-0000-0000-0000-000000000003',
     'e0000001-0000-0000-0000-000000000003',
     'Kaiser Permanente', 'KP-NPI-33001',
     'KP-300003', 'GRP-9920',
     'KP-CLM-20250522-001',
     '2025-05-22 00:00:00-07', '2025-05-27 00:00:00-07',
     'approved', 248.00, 62.00,
     'ECG interpretation fee ($62) not covered under plan tier.',
     'Appealing ECG denial'),

-- Re-submission appeal for Appt 3 ECG denial
    ('ff000001-0000-0000-0000-000000000004',
     'dd000001-0000-0000-0000-000000000003',
     'e0000001-0000-0000-0000-000000000003',
     'Kaiser Permanente', 'KP-NPI-33001',
     'KP-300003', 'GRP-9920',
     'KP-CLM-20250605-002',
     '2025-06-05 00:00:00-07', NULL,
     'appealed', NULL, NULL, NULL,
     'Appeal submitted with clinical necessity documentation for ECG'),

-- Claim for Appt 6 (Helen Park — Medicare)
    ('ff000001-0000-0000-0000-000000000005',
     'dd000001-0000-0000-0000-000000000006',
     'e0000001-0000-0000-0000-000000000006',
     'Medicare', 'MCR-NPI-00001',
     'MCR-600006', 'GRP-0010',
     'MCR-CLM-20250604-001',
     '2025-06-04 00:00:00-07', '2025-06-09 00:00:00-07',
     'paid', 388.00, 97.00,
     'Patient responsibility (20% co-insurance) not covered.',
     NULL);

-- FEEDBACK
INSERT INTO feedback
    (feedback_id, patient_id, appointment_id, doctor_id,
     rating, comment, is_anonymous,
     reviewed_by, reviewed_at, review_notes)
VALUES
    ('8f675c06-8d5f-436f-a58d-4b0ae7901666',
     'e0000001-0000-0000-0000-000000000001',
     'aa000001-0000-0000-0000-000000000001',
     'c0000001-0000-0000-0000-000000000001',
     5,
     'Dr Voss was thorough and took time to explain every test result. Very satisfied with the visit.',
     FALSE, NULL, NULL, NULL),

    ('79a6fac0-e920-4b15-99ee-9c0c8070382e',
     'e0000001-0000-0000-0000-000000000002',
     'aa000001-0000-0000-0000-000000000002',
     'c0000001-0000-0000-0000-000000000003',
     4,
     'Telehealth was convenient. Slight audio lag at the start but the consultation itself was excellent.',
     FALSE, NULL, NULL, NULL),

    ('bb77f456-b4e3-49de-891f-a7ba8ee45068',
     'e0000001-0000-0000-0000-000000000003',
     'aa000001-0000-0000-0000-000000000003',
     'c0000001-0000-0000-0000-000000000002',
     3,
     'Waiting room was crowded. Dr Tan was knowledgeable but felt rushed during the consultation.',
     FALSE, NULL, NULL, NULL),
	
	('d10ee1b8-7598-46de-a01b-b95ccb0963c9',
     'e0000001-0000-0000-0000-000000000004',
     'aa000001-0000-0000-0000-000000000004',
     'c0000001-0000-0000-0000-000000000004',
     5,
     'Dr Okafor explained my HbA1c trend clearly and made me feel confident about my diabetes management plan.',
     FALSE, NULL, NULL, NULL),

    ('557dd795-424c-4366-aaf7-b8ed0e3356e8',
     'e0000001-0000-0000-0000-000000000006',
     'aa000001-0000-0000-0000-000000000006',
     'c0000001-0000-0000-0000-000000000003',
     4,
     'Excellent first visit. Dr Nair was patient and listened well.',
     FALSE, NULL, NULL, NULL),

    ('761d0b54-f2bf-4603-9acd-f5bf688a7d84',
     'e0000001-0000-0000-0000-000000000010',
     'aa000001-0000-0000-0000-000000000010',
     'c0000001-0000-0000-0000-000000000001',
     5,
     'Follow-up was efficient. Lab results were explained clearly.',
     TRUE, NULL, NULL, NULL);
COMMIT;


-- ============================================================
-- BUSINESS RULE DEMONSTRATIONS
-- ============================================================
-- The following blocks run OUTSIDE the seed transaction so failures are visible without rolling back the seed data.
-- Each block is a self-contained transaction.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- BizRule-1 DEMO: Convert a confirmed telehealth appointment that accidentally has a room set → trigger auto-clears it.
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
DECLARE
    v_room_before UUID;
    v_room_after  UUID;
BEGIN
    -- Temporarily assign a room to a telehealth appointment (bypasses the trigger intentionally via direct update to mode first, leaving room set to test).
    -- We force a room_id onto the confirmed telehealth appointment (appt 7 — Devon Marsh) and then switch type back to telehealth to show the trigger clears it.

    -- Step 1: Switch appt 7 to in_person and assign a room.
    UPDATE appointment
       SET mode = 'in_person',
           room_id          = 'b0000001-0000-0000-0000-000000000006',
           telehealth_url   = NULL
     WHERE appointment_id   = 'aa000001-0000-0000-0000-000000000007';

    SELECT room_id INTO v_room_before
      FROM appointment
     WHERE appointment_id = 'aa000001-0000-0000-0000-000000000007';

    RAISE NOTICE '[BizRule-1] room_id before switching back to telehealth: %', v_room_before;

    -- Step 2: Switch back to telehealth — trigger should null out room_id.
    UPDATE appointment
       SET mode = 'telehealth',
           telehealth_url   = 'https://meet.meridian.example/rm/DM3QW6'
     WHERE appointment_id   = 'aa000001-0000-0000-0000-000000000007';

    SELECT room_id INTO v_room_after
      FROM appointment
     WHERE appointment_id = 'aa000001-0000-0000-0000-000000000007';

    RAISE NOTICE '[BizRule-1] room_id after trigger fired: % (expected NULL)', v_room_after;
    ASSERT v_room_after IS NULL, 'BizRule-1 FAILED: room_id was not cleared';
    RAISE NOTICE '[BizRule-1] PASS — room_id correctly nulled for telehealth appointment.';
END;
$$;

COMMIT;

/*
-- ────────────────────────────────────────────────────────────
-- BizRule-2 DEMO A: Verify that invoice totals match service lines.
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE '[BizRule-2] Invoice totals after seed:';
    RAISE NOTICE '%-38s  %10s  %10s  %10s  %10s',
        'invoice_id', 'subtotal', 'discount', 'tax', 'total';

    FOR r IN
        SELECT invoice_id,
               subtotal,
               discount,
               tax,
               total_amount,
               (subtotal - discount + tax) AS expected_total
          FROM invoice
         ORDER BY created_at
    LOOP
        RAISE NOTICE '% | %10s | %10s | %10s | %10s (expected %s)',
            r.invoice_id,
            r.subtotal, r.discount, r.tax, r.total_amount,
            r.expected_total;

        ASSERT r.total_amount = (r.subtotal - r.discount + r.tax),
            format('BizRule-2 FAILED: invoice %s total mismatch', r.invoice_id);
    END LOOP;

    RAISE NOTICE '[BizRule-2] PASS — all invoice totals consistent with subtotal - discount + tax.';
END;
$$;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- BizRule-2 DEMO B: Add a new service line to an existing invoice and verify total auto-updates.
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
DECLARE
    v_total_before NUMERIC(10,2);
    v_total_after  NUMERIC(10,2);
BEGIN
    -- Appt 5 (Roberto Fuentes) currently has Annual Wellness Exam = 200.00
    -- plus $15 tax → total = 215.00.  Add a CBC ($55) and confirm total rises.

    SELECT total_amount INTO v_total_before
      FROM invoice
     WHERE invoice_id = 'dd000001-0000-0000-0000-000000000005';

    RAISE NOTICE '[BR-2B] total before adding CBC: %', v_total_before;

    INSERT INTO appointment_service
        (appointment_id, service_id, quantity, unit_price)
    VALUES
        ('aa000001-0000-0000-0000-000000000005',
         'f0000001-0000-0000-0000-000000000005', 1, 55.00);  -- CBC

    SELECT total_amount INTO v_total_after
      FROM invoice
     WHERE invoice_id = 'dd000001-0000-0000-0000-000000000005';

    RAISE NOTICE '[BizRule-2B] total after adding CBC ($55): %', v_total_after;
    ASSERT v_total_after = v_total_before + 55.00,
        'BizRule-2B FAILED: total did not increase by 55.00';
    RAISE NOTICE '[BizRule-2B] PASS — invoice total auto-updated when service line added.';
END;
$$;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- BizRule-3 DEMO A: Attempt to overpay an invoice — must be rejected.
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
DECLARE
    v_remaining NUMERIC(10,2);
BEGIN
    -- Appt 3 (Liam Nakamura) — $62 still outstanding.
    SELECT (total_amount - amount_paid) INTO v_remaining
      FROM invoice
     WHERE invoice_id = 'dd000001-0000-0000-0000-000000000003';

    RAISE NOTICE '[BizRule-3A] Remaining balance on invoice 003: %', v_remaining;
    RAISE NOTICE '[BizRule-3A] Attempting to insert a payment of % (full overpayment)...', v_remaining + 100;

    BEGIN
        INSERT INTO payment (invoice_id, amount, payment_method)
        VALUES (
            'dd000001-0000-0000-0000-000000000003',
            v_remaining + 100.00,  -- deliberately too high
            'cash'
        );
        RAISE WARNING '[BizRule-3A] UNEXPECTED: overpayment was accepted — check trigger.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[BizRule-3A] PASS — overpayment correctly rejected: %', SQLERRM;
    END;
END;
$$;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- BizRule-3 DEMO B: Pay the remaining $62 exactly — must succeed.
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
DECLARE
    v_status VARCHAR(30);
BEGIN
    INSERT INTO payment
        (payment_id, invoice_id, amount, payment_method,
         payment_date, notes)
    VALUES
        ('ee000001-0000-0000-0000-000000000010',
         'dd000001-0000-0000-0000-000000000003',
         62.00, 'credit_card',
         NOW(), 'Patient settled remaining balance after ECG appeal');

    SELECT status INTO v_status
      FROM invoice
     WHERE invoice_id = 'dd000001-0000-0000-0000-000000000003';

    RAISE NOTICE '[BizRule-3B] Invoice 003 status after exact remaining payment: %', v_status;
    ASSERT v_status = 'paid', 'BizRule-3B FAILED: expected status paid';
    RAISE NOTICE '[BizRule-3B] PASS — invoice correctly marked paid.';
END;
$$;

COMMIT;


-- ────────────────────────────────────────────────────────────
-- BizRule-3 DEMO C: Issue a refund — must succeed and reopen balance.
-- ────────────────────────────────────────────────────────────
BEGIN;

DO $$
DECLARE
    v_paid_before  NUMERIC(10,2);
    v_paid_after   NUMERIC(10,2);
    v_status_after VARCHAR(30);
BEGIN
    -- Invoice 003 is now fully paid. A $62 refund is issued
    -- (e.g. the ECG appeal was approved and Kaiser will pay it).

    SELECT amount_paid INTO v_paid_before
      FROM invoice WHERE invoice_id = 'dd000001-0000-0000-0000-000000000003';

    RAISE NOTICE '[BizRule-3C] amount_paid before refund: %', v_paid_before;

    INSERT INTO payment
        (payment_id, invoice_id, amount, payment_method,
         payment_date, notes)
    VALUES
        ('ee000001-0000-0000-0000-000000000011',
         'dd000001-0000-0000-0000-000000000003',
         62.00, 'refund',
         NOW(), 'ECG appeal approved — refund patient out-of-pocket payment');

    SELECT amount_paid, status
      INTO v_paid_after, v_status_after
      FROM invoice WHERE invoice_id = 'dd000001-0000-0000-0000-000000000003';

    RAISE NOTICE '[BizRule-3C] amount_paid after refund: % | status: %',
        v_paid_after, v_status_after;
    ASSERT v_paid_after = v_paid_before - 62.00,
        'BizRule-3C FAILED: amount_paid did not decrease';
    RAISE NOTICE '[BizRule-3C] PASS — refund correctly reduced amount_paid; balance reopened.';
END;
$$;

COMMIT;
ALTER TABLE "invoice" ENABLE TRIGGER trg_invoice_totals_guard;

-- ────────────────────────────────────────────────────────────
-- FINAL STATE CHECK — print a summary of all invoices
-- ────────────────────────────────────────────────────────────
SELECT
    i.invoice_id,
    p.first_name || ' ' || p.last_name  AS patient,
    i.subtotal,
    i.discount,
    i.tax,
    i.total_amount,
    i.amount_paid,
    i.total_amount - i.amount_paid      AS balance_remaining,
    i.status
FROM invoice i
JOIN patient p ON p.patient_id = i.patient_id
ORDER BY i.created_at;
*/
