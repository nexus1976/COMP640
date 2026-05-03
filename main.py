import sys
from sqlalchemy import create_engine
import pandas as pd
from calendar import EPOCH
from datetime import datetime
connection_string = "postgresql+psycopg2://postgres:password@localhost:5432/comp640DB"
engine = create_engine(connection_string)

def is_valid_date(date_string, date_format='%Y-%m-%d'):
    try:
        datetime.strptime(date_string, date_format)
        return True
    except ValueError:
        return False

def query1():
    print("Running query 1: Doctor availability")
    doctor_id: str = input("Enter doctor UUID: ")
    start_date: str = input("Enter start date (YYYY-MM-DD): ")
    end_date: str = input("Enter end date (YYYY-MM-DD): ")
    duration_hours: int = int(input("Enter minimum duration (hours): "))
    if (not is_valid_date(start_date)) or (not is_valid_date(end_date)):
        raise ValueError("Invalid date format. Please use 'YYYY-MM-DD'.")
    query: str = f"""WITH MyDOWs AS (
                        SELECT 
                            generated_date::date AS calendar_date,
                            EXTRACT(DOW FROM generated_date) AS dow_numeric -- 0 (Sun) to 6 (Sat)
                        FROM generate_series(
                            '{start_date}'::timestamp, 
                            '{end_date}'::timestamp, 
                            interval '1 day'
                        ) AS generated_date
                    )
                    SELECT da.doctor_id, da.availability_id, da.slot_start, da.slot_end, MyDOWs.calendar_date
                    FROM public.doctor_availability da
                    INNER JOIN MyDOWs ON (da.day_of_week = MyDOWs.dow_numeric)
                    WHERE da.doctor_id = '{doctor_id}'
                    AND EXTRACT(EPOCH FROM (da.slot_end - da.slot_start)) / 3600 >= {duration_hours}
                    AND is_booked = false AND is_blocked = false"""
    df = pd.read_sql(query, engine)
    if df.empty:
        print("No available slots found for the given criteria.")
    else:
        print(df)

def query2():
    print("Running query 2: Clinic utilization report")
    query: str = f"""WITH
                    operating_hours AS (
                        SELECT location_id, day_of_week, MIN(slot_start) AS open_time, MAX(slot_end) AS close_time,
                            EXTRACT(EPOCH FROM (MAX(slot_end) - MIN(slot_start))) / 3600.0 AS operating_hrs
                        FROM public.doctor_availability
                        WHERE is_blocked = FALSE
                        GROUP BY location_id, day_of_week
                    ),
                    room_counts AS (
                        SELECT location_id, COUNT(*) AS active_rooms
                        FROM public.room
                        WHERE is_active = TRUE
                        GROUP BY location_id
                    ),
                    appointment_dates AS (
                        SELECT DISTINCT location_id, (scheduled_at AT TIME ZONE 'America/Los_Angeles')::date AS appt_date
                        FROM public.appointment
                        WHERE status NOT IN ('cancelled', 'no_show')
                    ),
                    available AS (
                        SELECT ad.location_id, ad.appt_date, EXTRACT(DOW FROM ad.appt_date)::smallint AS dow,
                            rc.active_rooms, oh.open_time, oh.close_time, oh.operating_hrs,
                            ROUND((rc.active_rooms * oh.operating_hrs)::numeric, 2) AS available_room_hrs
                        FROM appointment_dates ad
                        JOIN room_counts rc ON rc.location_id = ad.location_id
                        JOIN operating_hours oh ON oh.location_id = ad.location_id AND oh.day_of_week = EXTRACT(DOW FROM ad.appt_date)::smallint
                    ),
                    booked AS (
                        SELECT a.location_id, (a.scheduled_at AT TIME ZONE cl.timezone)::date AS appt_date, ROUND(SUM(a.duration_mins) / 60.0, 2) AS booked_room_hrs
                        FROM public.appointment a
                        JOIN clinic_location cl ON cl.location_id = a.location_id
                        WHERE a.mode = 'in_person' AND a.status NOT IN ('cancelled', 'no_show')
                        GROUP BY a.location_id, cl.timezone, (a.scheduled_at AT TIME ZONE cl.timezone)::date
                    )
                    SELECT
                        cl.name AS location_name,
                        av.appt_date AS report_date,
                        TO_CHAR(av.appt_date, 'Day') AS day_of_week,
                        TO_CHAR(av.open_time,  'HH12:MI AM') AS opens_at,
                        TO_CHAR(av.close_time, 'HH12:MI AM') AS closes_at,
                        av.active_rooms,
                        av.available_room_hrs,
                        COALESCE(bk.booked_room_hrs, 0.00) AS booked_room_hrs,
                        ROUND(COALESCE(bk.booked_room_hrs, 0.00) / NULLIF(av.available_room_hrs, 0) * 100, 1) AS utilization_pct
                    FROM available av
                    LEFT JOIN booked bk ON bk.location_id = av.location_id AND bk.appt_date = av.appt_date
                    JOIN clinic_location cl ON cl.location_id = av.location_id
                    ORDER BY av.appt_date, cl.name;"""
    df = pd.read_sql(query, engine)    
    print(df)

def query3():
    print("Running query 3: Doctor workload leaderboard")
    start_date: str = input("Enter start date (YYYY-MM-DD): ")
    end_date: str = input("Enter end date (YYYY-MM-DD): ")
    if (not is_valid_date(start_date)) or (not is_valid_date(end_date)):
        raise ValueError("Invalid date format. Please use 'YYYY-MM-DD'.")
    query: str = f"""SELECT RANK() OVER (ORDER BY COALESCE(SUM(i.total_amount), 0) DESC) AS revenue_rank,
                        d.first_name || ' ' || d.last_name AS doctor_name, d.specialty, cl.name AS primary_location,
                        COUNT(a.appointment_id) AS total_appointments, COALESCE(ROUND(SUM(i.total_amount), 2), 0.00) AS total_billed
                    FROM public.doctor d
                    LEFT JOIN public.clinic_location cl ON cl.location_id = d.location_id
                    LEFT JOIN public.appointment a ON a.doctor_id = d.doctor_id AND a.status NOT IN ('cancelled', 'no_show') 
                        AND (a.scheduled_at AT TIME ZONE cl.timezone)::date BETWEEN '{start_date}' AND '{end_date}'
                    LEFT JOIN public.invoice i ON i.appointment_id = a.appointment_id AND i.status NOT IN ('voided')
                    WHERE d.is_active = TRUE
                    GROUP BY d.doctor_id, d.first_name, d.last_name, d.specialty, cl.name
                    ORDER BY revenue_rank;"""
    df = pd.read_sql(query, engine)
    print(df)   

def query4():
    print("Running query 4: No-show rate analysis")
    query: str = f"""SELECT cl.name AS location_name, EXTRACT(YEAR FROM scheduled_at)::integer AS year, EXTRACT(MONTH FROM scheduled_at)::integer AS month,
                        d.first_name || ' ' || d.last_name AS doctor_name, d.specialty, COUNT(*) AS total_appointments,
                        COUNT(*) FILTER (WHERE status IN('cancelled', 'no_show')) AS cancelled_appointments,
                        (COUNT(*) FILTER (WHERE status IN ('cancelled', 'no_show')) * 100.0 / COUNT(*))::integer AS no_show_percentage
                    FROM public.appointment a
                    JOIN public.doctor d ON d.doctor_id = a.doctor_id
                    JOIN public.clinic_location cl ON cl.location_id = a.location_id
                    GROUP BY d.first_name, d.last_name, d.specialty, cl.name, a.doctor_id, a.location_id, year, month
                    ORDER BY year, month, cl.name, a.doctor_id;"""
    df = pd.read_sql(query, engine)
    print(df)    

def query5():
    print("Running query 5: Overlapping appointment detector (should return none)")
    query: str = f"""SELECT 'doctor' AS conflict_type, a1.appointment_id AS appointment_1, a2.appointment_id AS appointment_2, d.first_name || ' ' || d.last_name AS conflict_on,
                        a1.scheduled_at AS appt_1_start, a1.scheduled_at + (a1.duration_mins * INTERVAL '1 min') AS appt_1_end,
                        a2.scheduled_at AS appt_2_start, a2.scheduled_at + (a2.duration_mins * INTERVAL '1 min') AS appt_2_end
                    FROM public.appointment a1
                    JOIN public.appointment a2 ON a2.doctor_id = a1.doctor_id AND a2.appointment_id > a1.appointment_id 
                        AND a2.scheduled_at < a1.scheduled_at + (a1.duration_mins * INTERVAL '1 min')
                        AND a1.scheduled_at < a2.scheduled_at + (a2.duration_mins * INTERVAL '1 min')
                    JOIN public.doctor d ON d.doctor_id = a1.doctor_id
                    WHERE a1.status NOT IN ('cancelled', 'no_show') AND a2.status NOT IN ('cancelled', 'no_show')
                    UNION ALL
                    SELECT 'room' AS conflict_type, a1.appointment_id AS appointment_1, a2.appointment_id AS appointment_2, cl.name || ' — Room ' || r.room_number AS conflict_on,
                        a1.scheduled_at AS appt_1_start, a1.scheduled_at + (a1.duration_mins * INTERVAL '1 min') AS appt_1_end,
                        a2.scheduled_at AS appt_2_start, a2.scheduled_at + (a2.duration_mins * INTERVAL '1 min') AS appt_2_end
                    FROM public.appointment a1
                    JOIN public.appointment a2 ON a2.room_id = a1.room_id AND a2.appointment_id > a1.appointment_id
                        AND a2.scheduled_at < a1.scheduled_at + (a1.duration_mins * INTERVAL '1 min')
                        AND a1.scheduled_at < a2.scheduled_at + (a2.duration_mins * INTERVAL '1 min')
                    JOIN public.room r ON r.room_id = a1.room_id
                    JOIN public.clinic_location cl ON cl.location_id = r.location_id
                    WHERE a1.status NOT IN ('cancelled', 'no_show') AND a2.status NOT IN ('cancelled', 'no_show') AND a1.room_id IS NOT NULL
                    ORDER BY conflict_type, appt_1_start;"""
    df = pd.read_sql(query, engine)    
    if df.empty:
        print("No overlapping appointments found.")
    else:
        print(df)

def query6():
    print("Running query 6: Outstanding balances report")
    balanceMin: float = float(input("Enter minimum outstanding balance to report: "))
    query: str = f"""SELECT p.first_name || ' ' || p.last_name AS patient_name, p.email, p.phone,
                        ROUND(SUM(i.total_amount - i.amount_paid), 2) AS total_outstanding, MAX(pay.payment_date) AS last_payment_date
                    FROM public.patient p
                    JOIN public.invoice i ON i.patient_id = p.patient_id
                    LEFT JOIN public.payment pay ON pay.invoice_id = i.invoice_id
                    WHERE i.status NOT IN ('voided', 'paid')
                    GROUP BY p.patient_id, p.first_name, p.last_name, p.email, p.phone
                    HAVING SUM(i.total_amount - i.amount_paid) > {balanceMin}
                    ORDER BY total_outstanding DESC;"""
    df = pd.read_sql(query, engine)
    if df.empty:
        print("No patients with outstanding balances above the specified minimum.")
    else:
        print(df)    

def query7():
    print("Running query 7: Revenue by service type")
    query: str = f"""SELECT DATE_TRUNC('month', a.scheduled_at AT TIME ZONE cl.timezone)::date AS month,
                        s.service_type AS service_category, COUNT(ast.appointment_service_id) AS total_services, ROUND(SUM(ast.quantity * ast.unit_price), 2) AS total_revenue
                    FROM public.appointment_service ast
                    JOIN appointment a ON a.appointment_id = ast.appointment_id
                    JOIN service s ON s.service_id = ast.service_id
                    JOIN clinic_location cl ON cl.location_id = a.location_id
                    WHERE a.status NOT IN ('cancelled', 'no_show')
                    GROUP BY DATE_TRUNC('month', a.scheduled_at AT TIME ZONE cl.timezone), s.service_type
                    ORDER BY month, total_revenue DESC;"""
    df = pd.read_sql(query, engine)
    print(df)    

def query8():
    print("Running query 8: High-frequency patients")
    min_appointments: int = int(input("Enter minimum number of appointments in the last 6 months: "))
    query: str = f"""SELECT p.first_name || ' ' || p.last_name AS patient_name, p.email, p.phone,
                        COUNT(DISTINCT a.appointment_id) AS appointment_count, STRING_AGG(DISTINCT COALESCE(s.name, ''), ', ' ORDER BY COALESCE(s.name, '')) AS services
                    FROM public.patient p
                    JOIN public.appointment a ON a.patient_id = p.patient_id
                    LEFT JOIN public.appointment_service ast ON ast.appointment_id = a.appointment_id
                    LEFT JOIN public.service s ON s.service_id = ast.service_id
                    WHERE a.scheduled_at >= NOW() - INTERVAL '6 months'
                    GROUP BY p.patient_id, p.first_name, p.last_name, p.email, p.phone
                    HAVING COUNT(DISTINCT a.appointment_id) >= {min_appointments}
                    ORDER BY appointment_count DESC;"""
    df = pd.read_sql(query, engine)
    print(df)

def query9():
    print("Running query 9: Top-K doctors by growth")
    topKDoctors: int = int(input("Enter the number of top doctors to display: "))
    query: str = f"""WITH monthly_revenue AS (
                            SELECT a.doctor_id, DATE_TRUNC('month', a.scheduled_at AT TIME ZONE cl.timezone) AS month, ROUND(SUM(ast.quantity * ast.unit_price), 2) AS revenue
                            FROM public.appointment a
                            JOIN public.clinic_location cl ON cl.location_id = a.location_id
                            JOIN public.appointment_service ast ON ast.appointment_id = a.appointment_id
                            WHERE a.status NOT IN ('cancelled', 'no_show')
                                AND DATE_TRUNC('month', a.scheduled_at AT TIME ZONE cl.timezone) >= DATE_TRUNC('month', NOW() - INTERVAL '1 month')
                            GROUP BY a.doctor_id, DATE_TRUNC('month', a.scheduled_at AT TIME ZONE cl.timezone)
                        )
                        SELECT d.first_name || ' ' || d.last_name AS doctor_name, d.specialty,
                            COALESCE(this.revenue, 0.00) AS revenue_this_month, COALESCE(last.revenue, 0.00) AS revenue_last_month,
                            ROUND(COALESCE(this.revenue, 0) - COALESCE(last.revenue, 0), 2) AS revenue_delta,
                            CASE
                                WHEN COALESCE(last.revenue, 0) = 0 THEN NULL
                                ELSE ROUND((COALESCE(this.revenue, 0) - last.revenue) / last.revenue * 100, 1)
                            END AS growth_pct,
                            RANK() OVER (ORDER BY COALESCE(this.revenue, 0) DESC) AS revenue_rank
                        FROM public.doctor d
                        JOIN clinic_location cl ON cl.location_id = d.location_id
                        LEFT JOIN monthly_revenue this ON this.doctor_id = d.doctor_id AND this.month = DATE_TRUNC('month', NOW())
                        LEFT JOIN monthly_revenue last ON last.doctor_id = d.doctor_id AND last.month = DATE_TRUNC('month', NOW() - INTERVAL '1 month')
                        WHERE d.is_active = TRUE AND COALESCE(this.revenue, 0) > 0
                        ORDER BY revenue_rank
                        LIMIT {topKDoctors};"""
    df = pd.read_sql(query, engine)
    print(df) 

def query10():
    print("Running query 10: List of Top-K doctors who issued the most prescriptions in a specific location")
    topKDoctors: int = int(input("Enter the number of top doctors to display per location: "))
    query: str = f"""WITH ranked AS (
                        SELECT cl.name AS location_name, d.first_name || ' ' || d.last_name AS doctor_name, d.specialty,
                        COUNT(rx.prescription_id) AS total_prescriptions,
                        RANK() OVER (PARTITION BY cl.location_id ORDER BY COUNT(rx.prescription_id) DESC) AS location_rank
                        FROM public.doctor d
                        JOIN public.prescription rx ON rx.doctor_id = d.doctor_id
                        JOIN public.clinic_location cl ON cl.location_id = d.location_id
                        WHERE d.is_active = TRUE
                        GROUP BY cl.location_id, cl.name, d.doctor_id, d.first_name, d.last_name, d.specialty
                    )
                    SELECT * 
                    FROM ranked
                    WHERE location_rank <= {topKDoctors}
                    ORDER BY location_name, location_rank;"""
    # If 2 doctors are tied for a given rank in terms of prescriptions issued at a location, both will be shown.
    df = pd.read_sql(query, engine)    
    print(df)

def main():
    while True:
        print("\nChoose a query to run (1-10) or 'q' to quit:")
        print("\n1: Doctor availability")
        print("2: Clinic utilization report")
        print("3: Doctor workload leaderboard")
        print("4: No-show rate analysis")
        print("5: Overlapping appointment detector (should return none)")
        print("6: Outstanding balances report")
        print("7: Revenue by service type")
        print("8: High-frequency patients")
        print("9: Top-K doctors by growth")
        print("10: List of Top-K doctors who issued the most prescriptions in a specific location")
        choice = input("Enter your choice: ").strip()
        if choice.lower() == 'q':
            print("Exiting...")
            break
        try:
            num = int(choice)
            if 1 <= num <= 10:
                func_name = f"query{num}"
                func = globals()[func_name]
                func()
            else:
                print("Invalid choice. Please enter a number between 1 and 10.")
        except ValueError:
            print("Invalid input. Please enter a number or 'q'.")

if __name__ == "__main__":
    main()